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
  alias Engine.Ethereum.Event.RootChainCoordinator.SyncGuide
  alias Engine.Ethereum.RootChain.Event

  # use Spandex.Decorators

  defstruct service_name: nil,
            # what's being exchanged with `RootChainCoordinator` - the point in root chain until where it processed
            synced_height: 0,
            cached: %{
              data: [],
              request_max_size: 1000,
              # until which height the events have been pulled and cached
              events_upper_bound: 0
            },
            ets: nil

  @type t() :: %__MODULE__{
          service_name: atom(),
          cached: %{
            data: list(Event.t()),
            request_max_size: pos_integer(),
            events_upper_bound: non_neg_integer()
          },
          ets: atom()
        }

  @doc """
  Initializes the listener logic based on its configuration and the last persisted Ethereum height, till which events
  were processed
  """
  @spec init(atom(), non_neg_integer(), non_neg_integer(), atom()) :: t()
  def init(service_name, last_synced_ethereum_height, request_max_size, ets) do
    %__MODULE__{
      synced_height: last_synced_ethereum_height,
      service_name: service_name,
      cached: %{
        data: [],
        request_max_size: request_max_size,
        events_upper_bound: last_synced_ethereum_height
      },
      ets: ets
    }
  end

  @doc """
  Returns range Ethereum height to download
  """
  @spec get_events_range_for_download(t(), SyncGuide.t()) ::
          {:dont_fetch_events, t()} | {:get_events, {non_neg_integer, non_neg_integer}, t()}
  def get_events_range_for_download(state, sync_guide) do
    case sync_guide.sync_height <= state.cached.events_upper_bound do
      true ->
        {:dont_fetch_events, state}

      _ ->
        # grab as much as allowed, but not higher than current root_chain_height and at least as much as needed to sync
        # both root_chain_height and sync_height are assumed to have any required finality margins applied by caller
        root_chain_height = sync_guide.root_chain_height
        events_upper_bound = state.cached.events_upper_bound
        request_max_size = state.cached.request_max_size

        next_upper_bound = max(min(root_chain_height, events_upper_bound + request_max_size), sync_guide.sync_height)

        {:get_events, {events_upper_bound + 1, next_upper_bound},
         struct(state, cached: %{state.cached | events_upper_bound: next_upper_bound})}
    end
  end

  @doc """
  Stores the freshly fetched ethereum events into a memory-cache
  """
  # @decorate span(service: :ethereum_event_listener, type: :backend, name: "add_new_events/2")
  @spec add_new_events(t(), list(Event.t())) :: t()
  def add_new_events(state, new_events) do
    %__MODULE__{state | cached: %{state.cached | data: state.cached.data ++ new_events}}
  end

  @doc """
  Pop some ethereum events stored in the memory-cache, up to a certain height
  """
  # @decorate span(service: :ethereum_event_listener, type: :backend, name: "get_events/2")
  @spec get_events(t(), non_neg_integer) :: {:ok, list(Event.t()), non_neg_integer, t()}
  def get_events(state, new_sync_height) do
    {events, new_data} = Enum.split_while(state.cached.data, fn %{eth_height: height} -> height <= new_sync_height end)

    new_state =
      struct(state,
        cached: Map.put(state.cached, :data, new_data),
        synced_height: max(state.synced_height, new_sync_height)
      )

    {:ok, events, new_state.synced_height, new_state}
  end
end
