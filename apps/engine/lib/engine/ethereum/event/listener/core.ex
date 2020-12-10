defmodule Engine.Ethereum.Event.Listener.Core do
  @moduledoc """
  Logic module for the `Listener`

  Responsible for:
    - deciding what ranges of Ethereum events should be fetched from the Ethereum node
    - deciding the right size of event batches to read (too little means many RPC requests, too big can timeout)
    - deciding what to check in into the `OMG.Coordinator`
    - deciding what to put into the database in terms of Ethereum height till which the events are already processed

  Leverages a rudimentary in-memory cache for events, to be able to ask for right-sized batches of events
  """
  alias Engine.Ethereum.Event.Coordinator.SyncGuide
  # synced_height is what's being exchanged with `RootChainCoordinator`.
  # The point in root chain until where it processed
  defstruct service_name: nil,
            synced_height: 0,
            request_max_size: 1000,
            ets: nil

  @type event :: %{eth_height: non_neg_integer()}

  @type t() :: %__MODULE__{
          service_name: atom(),
          synced_height: integer(),
          request_max_size: pos_integer(),
          ets: atom()
        }

  @doc """
  Initializes the listener logic based on its configuration and the last persisted Ethereum height, till which events
  were processed
  """
  @spec init(atom(), non_neg_integer(), non_neg_integer(), atom()) :: t()
  def init(service_name, last_synced_ethereum_height, request_max_size, ets) do
    %__MODULE__{
      service_name: service_name,
      synced_height: last_synced_ethereum_height,
      request_max_size: request_max_size,
      ets: ets
    }
  end

  @doc """
  Returns the events range -
  - from (inclusive!),
  - to (inclusive!)
  that needs to be scraped and sets synced_height in the state.

  """
  @spec calc_events_range_set_height(t(), SyncGuide.t()) ::
          {:dont_fetch_events, t()} | {{non_neg_integer, non_neg_integer}, t()}
  def calc_events_range_set_height(state, sync_guide) do
    case sync_guide.sync_height <= state.synced_height do
      true ->
        {:dont_fetch_events, state}

      _ ->
        # if sync_guide.sync_height has applied margin (reorg protection)
        # the only thing we need to be aware of is that we don't go pass that!
        # but we want to move as fast as possible so we try to fetch as much as we can (request_max_size)
        first_not_visited = state.synced_height + 1
        # if first not visited = 1, and request max size is 10
        # it means we can scrape AT MOST request_max_size events
        max_height = state.request_max_size - 1
        upper_bound = min(sync_guide.sync_height, first_not_visited + max_height)

        {{first_not_visited, upper_bound}, %{state | synced_height: upper_bound}}
    end
  end
end
