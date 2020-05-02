defmodule Engine.Ethereum.Event.EventListener do
  @moduledoc """
  GenServer running the listener.

  Periodically fetches events made on dynamically changing block range
  from the root chain contract and feeds them to a callback.

  It is **not** responsible for figuring out which ranges of Ethereum blocks are eligible to scan and when, see
  `RootChainCoordinator` for that.
  The `RootChainCoordinator` provides the `SyncGuide` that indicates what's eligible to scan, taking into account:
   - finality margin
   - mutual ordering and dependencies of various types of Ethereum events to be respected.

  It **is** responsible for processing all events from all blocks and processing them only once.

  It accomplishes that by keeping a persisted value in `OMG.DB` and its state that reflects till which Ethereum height
  the events were processed (`synced_height`).
  This `synced_height` is updated after every batch of Ethereum events get successfully consumed by
  `callbacks.process_events_callback`, as called in `sync_height/2`, together with all the `OMG.DB` updates this
  callback returns, atomically.
  The key in `PG` used to persist `synced_height` is defined by the value of `service_name`.

  What specific Ethereum events it fetches, and what it does with them is up to predefined `callbacks`.

  See `EventListener.Core` for the implementation of the business logic for the listener.
  """
  use GenServer

  #  use Spandex.Decorators

  alias Engine.Ethereum.Event.EventListener.Core
  alias Engine.Ethereum.Event.EventListener.Storage
  alias Engine.Ethereum.Event.RootChainCoordinator
  alias Engine.SyncedHeight

  require Logger

  ### Client

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    name = Keyword.fetch!(opts, :service_name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Returns child_specs for the given `EventListener` setup, to be included e.g. in Supervisor's children.
  See `handle_continue/2` for the required keyword arguments.
  """
  @spec prepare_child(keyword()) :: Supervisor.child_spec()
  def prepare_child(opts) do
    name = Keyword.fetch!(opts, :service_name)
    %{id: name, start: {__MODULE__, :start_link, [opts]}, shutdown: :brutal_kill, type: :worker}
  end

  ### Server

  @doc """
  Initializes the GenServer state, most work done in `handle_continue/2`.
  """
  def init(opts) do
    {:ok, opts, {:continue, :setup}}
  end

  @doc """
  Reads the status of listening (till which Ethereum height were the events processed) from the `OMG.DB` and initializes
  the logic `EventListener.Core` with it. Does an initial `RootChainCoordinator.check_in` with the
  Ethereum height it last stopped on. Next, it continues to monitor and fetch the events as usual.
  """
  def handle_continue(:setup, opts) do
    contract_deployment_height = Keyword.fetch!(opts, :contract_deployment_height)
    service_name = Keyword.fetch!(opts, :service_name)
    get_events_callback = Keyword.fetch!(opts, :get_events_callback)
    process_events_callback = Keyword.fetch!(opts, :process_events_callback)
    metrics_collection_interval = Keyword.fetch!(opts, :metrics_collection_interval)
    ets = Keyword.fetch!(opts, :ets)
    _ = Logger.info("Starting #{inspect(__MODULE__)} for #{service_name}.")

    # we don't need to ever look at earlier than contract deployment
    last_event_block_height =
      max_of_three(
        Storage.get_local_synced_height(service_name, ets),
        contract_deployment_height,
        SyncedHeight.get_height(service_name)
      )

    request_max_size = 1000

    state =
      Core.init(
        service_name,
        last_event_block_height,
        request_max_size,
        ets
      )

    callbacks = %{
      get_events_callback: get_events_callback,
      process_events_callback: process_events_callback
    }

    :ok = Bus.subscribe({:root_chain, "ethereum_new_height"}, link: true)
    :ok = RootChainCoordinator.check_in(state.synced_height, service_name)
    {:ok, _} = :timer.send_interval(metrics_collection_interval, self(), :send_metrics)

    _ = Logger.info("Started #{inspect(__MODULE__)} for #{service_name}, synced_height: #{state.synced_height}")

    {:noreply, {state, callbacks}}
  end

  def handle_info(:send_metrics, {state, callbacks}) do
    :ok = :telemetry.execute([:process, __MODULE__], %{}, state)
    {:noreply, {state, callbacks}}
  end

  @doc """
  Main worker function, called on a cadence as initialized in `handle_continue/2`.
  The cadence is every change of ethereum height, notified via Bus.

  Does the following:
   - asks `RootChainCoordinator` about how to sync, with respect to other services listening to Ethereum
   - (`sync_height/2`) figures out what is the suitable range of Ethereum blocks to download events for
   - (`sync_height/2`) if necessary fetches those events to the in-memory cache in `OMG.EthereumEventListener.Core`
   - (`sync_height/2`) executes the related event-consuming callback with events as arguments
   - (`sync_height/2`) does `OMG.DB` updates that persist the processes Ethereum height as well as whatever the
      callbacks returned to persist
   - (`sync_height/2`) `RootChainCoordinator.check_in` to tell the rest what Ethereum height was processed.
  """
  def handle_info({:internal_event_bus, :ethereum_new_height, _new_height}, {state, callbacks}) do
    case RootChainCoordinator.get_sync_info() do
      :nosync ->
        :ok = RootChainCoordinator.check_in(state.synced_height, state.service_name)
        {:noreply, {state, callbacks}}

      sync_info ->
        new_state = sync_height(state, callbacks, sync_info)
        {:noreply, {new_state, callbacks}}
    end
  end

  def handle_cast(:sync, {state, callbacks}) do
    case RootChainCoordinator.get_sync_info() do
      :nosync ->
        :ok = RootChainCoordinator.check_in(state.synced_height, state.service_name)
        {:noreply, {state, callbacks}}

      sync_info ->
        new_state = sync_height(state, callbacks, sync_info)
        {:noreply, {new_state, callbacks}}
    end
  end

  defp sync_height(state, callbacks, sync_guide) do
    {:ok, events, height_to_check_in, new_state} =
      state
      |> Core.get_events_range_for_download(sync_guide)
      |> update_event_cache(callbacks.get_events_callback)
      |> Core.get_events(sync_guide.sync_height)

    # process_events_callback sorts persistence!
    :ok = callbacks.process_events_callback.(events)
    :ok = :telemetry.execute([:process, __MODULE__], %{events: events}, new_state)
    :ok = publish_events(events)
    :ok = Storage.update_synced_height(new_state.service_name, height_to_check_in, new_state.ets)
    :ok = RootChainCoordinator.check_in(height_to_check_in, state.service_name)

    new_state
  end

  defp update_event_cache({:get_events, {from, to}, state}, get_events_callback) do
    {:ok, new_events} = get_events_callback.(from, to)
    Core.add_new_events(state, new_events)
  end

  defp update_event_cache({:dont_fetch_events, state}, _callback) do
    state
  end

  defp publish_events([%{event_signature: event_signature} | _] = data) do
    [event_signature, _] = String.split(event_signature, "(")

    {:root_chain, event_signature}
    |> Bus.Event.new(:data, data)
    |> Bus.direct_local_broadcast()
  end

  defp publish_events([]), do: :ok

  defp max_of_three(a, b, c) do
    a
    |> max(b)
    |> max(c)
  end
end
