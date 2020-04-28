defmodule Engine.Ethereum.RootChainCoordinator.Core do
  @moduledoc """
  Synchronizes multiple log-reading services on root chain height.
  Each synchronized service must have a unique name.
  Service reports its height by calling 'check_in'.
  After all the services are checked in, coordinator returns currently synchronizable height,
  for every service which asks by calling `RootChainCoordinator.get_height()`

  In case a service fails, it is checked out and coordinator does not resume until the missing service checks_in again.
  Coordinator periodically updates root chain height, looks after finality margins and ensures geth-queries aren't huge.

  Coordinator is forgiving in terms of height backoffs:
    - if the root chain's height backs off, it will treat it as an interim state and ignore the back off (noop)
    - if any of the coordinated services backs off, it will register the backed off height and coordinate acordingly.
      All services must accept a `SyncGuide` that tells them they should back off. All services must ensure this doesn't
      cause them to process any events twice! All services must ensure they process everything!
  """

  alias Engine.Ethereum.RootChainCoordinator.Service
  alias Engine.Ethereum.RootChainCoordinator.SyncGuide

  require Logger

  defstruct configs_services: %{}, root_chain_height: 0, services: %{}

  @type config_t :: keyword()
  @type configs_services :: %{required(atom()) => config_t()}

  @type t() :: %__MODULE__{
          configs_services: configs_services,
          root_chain_height: non_neg_integer(),
          services: %{required(atom()) => Service.t()}
        }

  @type check_in_error_t :: {:error, :service_not_allowed}

  @type ethereum_heights_result_t() :: %{atom() => non_neg_integer()}

  # RootChainCoordinator is also checking if queries to Ethereum client don't get huge
  @maximum_leap_forward 2_500

  @doc """
  Initializes the state of the logic module.
   - `configs_services` - configs of services that are being synchronized.
     A map of the form `%{service_name => config}`. The `config`s are keyword lists with the following options:
       - `:finality_margin` - number of Ethereum block confirmations to count before recognizing an event
       - `:waits_for` - a list of other services, which should sync first. Each service in this list can be an atom,
         being the name of the service, or a `{service_name, :no_margin}` pair, if the waiting should bypass the
         finality margin of the awaited process.

     An example config can be seen in `OMG.Watcher.CoordinatorSetup`
   - `root_chain_height` - current root chain height
  """
  @spec init(map(), non_neg_integer()) :: t()
  def init(configs_services, root_chain_height) do
    %__MODULE__{configs_services: configs_services, root_chain_height: root_chain_height}
  end

  @doc """
  Updates Ethereum height on which a service is synchronized.
  """
  @spec check_in(t(), pid(), pos_integer(), atom()) :: {:ok, t()} | check_in_error_t()
  def check_in(state, pid, service_height, service_name) do
    if allowed?(state.configs_services, service_name) do
      update_service_synced_height(pid, service_height, service_name, state)
    else
      {:error, :service_not_allowed}
    end
  end

  @doc """
  Sets root chain height, only allowing to progress, in case Ethereum RPC reports an earlier height
  """
  @spec update_root_chain_height(t(), pos_integer()) :: {:ok, t()}
  def update_root_chain_height(state, new_height) do
    {:ok, %{state | root_chain_height: max(state.root_chain_height, new_height)}}
  end

  @doc """
  Provides synchronization guide to a service which asks
  """
  @spec get_synced_info(t(), atom() | pid()) :: SyncGuide.t() | :nosync
  def get_synced_info(state, pid) when is_pid(pid) do
    service = Enum.find(state.services, fn service -> match?({_, %Service{pid: ^pid}}, service) end)

    case service do
      {service_name, _} -> get_synced_info(state, service_name)
      nil -> :nosync
    end
  end

  def get_synced_info(state, service_name) do
    case all_services_checked_in?(state) do
      true ->
        config = state.configs_services[service_name]
        current_sync_height = state.services[service_name].synced_height

        next_sync_height =
          config
          |> Keyword.get(:waits_for, [])
          |> get_height_of_awaited(state)
          |> consider_finality(state.configs_services[service_name], state.root_chain_height)
          |> min(current_sync_height + @maximum_leap_forward)
          |> min(state.root_chain_height)
          |> max(0)

        finality_bearing_root = max(0, state.root_chain_height - finality_margin_for(config))

        %SyncGuide{sync_height: next_sync_height, root_chain_height: finality_bearing_root}

      _ ->
        :nosync
    end
  end

  @doc """
  Gets all the ethereum heights reported as synced to by the services (and the main root chain height acknowledged)
  """
  @spec get_ethereum_heights(t()) :: ethereum_heights_result_t()
  def get_ethereum_heights(state) do
    base_result_map = %{root_chain_height: state.root_chain_height}
    Enum.into(state.services, base_result_map, fn {name, %Service{synced_height: height}} -> {name, height} end)
  end

  defp finality_margin_for(config), do: Keyword.get(config, :finality_margin, 0)
  defp finality_margin_for!(config), do: Keyword.fetch!(config, :finality_margin)

  # ensures we don't exceed the allowed finality margin applied to the root_chain_height
  defp consider_finality(sync_height, config, root_chain_height) do
    min(sync_height, root_chain_height - finality_margin_for(config))
  end

  # get the earliest-synced of all of the services we're waiting for, if any, if none then root chain height
  defp get_height_of_awaited([], state) do
    # wait for nothing so root chain is the limit
    state.root_chain_height
  end

  defp get_height_of_awaited(single_awaited, state) when is_atom(single_awaited) do
    # we wait for a single service so get that
    state.services[single_awaited].synced_height
  end

  defp get_height_of_awaited({single_awaited, :no_margin}, state) do
    # in this clause we're waiting on a service, but skipping ahead its particular finality margin
    get_height_of_awaited(single_awaited, state) + finality_margin_for!(state.configs_services[single_awaited])
  end

  defp get_height_of_awaited(awaited, state) do
    # we're waiting for multiple services, so iterate the list and get the least synced height
    awaited |> Enum.map(&get_height_of_awaited(&1, state)) |> Enum.min()
  end

  defp all_services_checked_in?(state) do
    sort = fn map -> map |> Map.keys() |> Enum.sort() end
    sort.(state.configs_services) == sort.(state.services)
  end

  defp allowed?(configs_services, service_name), do: Map.has_key?(configs_services, service_name)

  defp update_service_synced_height(pid, new_reported_sync_height, service_name, state) do
    new_service_state = %Service{synced_height: new_reported_sync_height, pid: pid}
    {:ok, %{state | services: Map.put(state.services, service_name, new_service_state)}}
  end
end