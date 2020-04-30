defmodule Engine.Ethereum.Event.EventListener.Core do
  @moduledoc """
  Logic module for the `OMG.EthereumEventListener`

  Responsible for:
    - deciding what ranges of Ethereum events should be fetched from the Ethereum node
    - deciding the right size of event batches to read (too little means many RPC requests, too big can timeout)
    - deciding what to check in into the `OMG.RootChainCoordinator`
    - deciding what to put into the `OMG.DB` in terms of Ethereum height till which the events are already processed

  Leverages a rudimentary in-memory cache for events, to be able to ask for right-sized batches of events
  """
  alias Engine.Ethereum.RootChainCoordinator.SyncGuide

  # use Spandex.Decorators

  defstruct synced_height_update_key: nil,
            service_name: nil,
            # what's being exchanged with `RootChainCoordinator` - the point in root chain until where it processed
            synced_height: 0,
            ethereum_events_check_interval_ms: nil,
            cached: %{
              data: [],
              request_max_size: 1000,
              # until which height the events have been pulled and cached
              events_upper_bound: 0
            }

  @type event :: %{eth_height: non_neg_integer()}

  @type t() :: %__MODULE__{
          synced_height_update_key: atom(),
          service_name: atom(),
          cached: %{
            data: list(event),
            request_max_size: pos_integer(),
            events_upper_bound: non_neg_integer()
          },
          ethereum_events_check_interval_ms: non_neg_integer()
        }

  @doc """
  Initializes the listener logic based on its configuration and the last persisted Ethereum height, till which events
  were processed
  """
  @spec init(atom(), atom(), non_neg_integer(), non_neg_integer(), non_neg_integer()) :: {t(), non_neg_integer()}

  def init(
        update_key,
        service_name,
        last_synced_ethereum_height,
        ethereum_events_check_interval_ms,
        request_max_size \\ 1000
      ) do
    initial_state = %__MODULE__{
      synced_height_update_key: update_key,
      synced_height: last_synced_ethereum_height,
      service_name: service_name,
      cached: %{
        data: [],
        request_max_size: request_max_size,
        events_upper_bound: last_synced_ethereum_height
      },
      ethereum_events_check_interval_ms: ethereum_events_check_interval_ms
    }

    {initial_state, get_height_to_check_in(initial_state)}
  end

  @doc """
  Provides a uniform way to get the height to check in.

  Every call to RootChainCoordinator.check_in should use value taken from this, after all mutations to the state
  """
  @spec get_height_to_check_in(t()) :: non_neg_integer()
  def get_height_to_check_in(state), do: state.synced_height

  @doc """
  Returns range Ethereum height to download
  """
  # @decorate span(service: :ethereum_event_listener, type: :backend, name: "get_events_range_for_download/2")
  @spec get_events_range_for_download(t(), SyncGuide.t()) ::
          {:dont_fetch_events, t()} | {:get_events, {non_neg_integer, non_neg_integer}, t()}
  def get_events_range_for_download(%__MODULE__{cached: %{events_upper_bound: upper}} = state, %SyncGuide{
        sync_height: sync_height
      })
      when sync_height <= upper do
    {:dont_fetch_events, state}
  end

  # @decorate span(service: :ethereum_event_listener, type: :backend, name: "get_events_range_for_download/2")
  def get_events_range_for_download(state, sync_guide) do
    # grab as much as allowed, but not higher than current root_chain_height and at least as much as needed to sync
    # NOTE: both root_chain_height and sync_height are assumed to have any required finality margins applied by caller
    next_upper_bound =
      max(
        min(sync_guide.root_chain_height, state.cached.events_upper_bound + state.cached.request_max_size),
        sync_guide.sync_height
      )

    {:get_events, {state.cached.events_upper_bound + 1, next_upper_bound},
     struct(state, cached: %{state.cached | events_upper_bound: next_upper_bound})}
  end

  @doc """
  Stores the freshly fetched ethereum events into a memory-cache
  """
  # @decorate span(service: :ethereum_event_listener, type: :backend, name: "add_new_events/2")
  @spec add_new_events(t(), list(event)) :: t()
  def add_new_events(state, new_events) do
    %__MODULE__{state | cached: %{state.cached | data: state.cached.data ++ new_events}}
  end

  @doc """
  Pop some ethereum events stored in the memory-cache, up to a certain height
  """
  # @decorate span(service: :ethereum_event_listener, type: :backend, name: "get_events/2")
  @spec get_events(t(), non_neg_integer) :: {:ok, list(event), list(), non_neg_integer, t()}
  def get_events(state, new_sync_height) do
    {events, new_data} = Enum.split_while(state.cached.data, fn %{eth_height: height} -> height <= new_sync_height end)

    new_state =
      state
      |> Map.update!(:synced_height, &max(&1, new_sync_height))
      |> Map.update!(:cached, &%{&1 | data: new_data})
      |> struct!()

    height_to_check_in = get_height_to_check_in(new_state)
    db_update = [{:put, state.synced_height_update_key, height_to_check_in}]
    {:ok, events, db_update, height_to_check_in, new_state}
  end
end
