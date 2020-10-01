defmodule Engine.Ethereum.SyncSupervisor do
  @moduledoc """
   Ethereum listeners top level supervisor.
  """
  use Supervisor

  alias Engine.Callbacks.Deposit
  alias Engine.Callbacks.ExitStarted
  alias Engine.Callbacks.InFlightExitStarted
  alias Engine.Callbacks.Piggyback
  alias Engine.Configuration
  alias Engine.Ethereum.ChildObserver
  alias Engine.Ethereum.Event.Aggregator
  alias Engine.Ethereum.Event.Aggregator.Storage, as: AggregatorStorage
  alias Engine.Ethereum.Event.Coordinator
  alias Engine.Ethereum.Event.Coordinator.Setup
  alias Engine.Ethereum.Event.Listener
  alias Engine.Ethereum.Event.Listener.Storage, as: ListenerStorage

  require Logger

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    opts = [strategy: :one_for_one]

    _ = Logger.info("Starting #{__MODULE__}")

    children = children(args)
    Supervisor.init(children, opts)
  end

  defp children(args) do
    monitor = Keyword.fetch!(args, :monitor)
    contract_deployment_height = Keyword.fetch!(args, :contract_deployment_height)
    finality_margin = Configuration.finality_margin()
    metrics_collection_interval = Configuration.metrics_collection_interval()
    contracts = Configuration.contracts()
    url = Configuration.url()

    [
      {Coordinator,
       Setup.coordinator_setup(
         metrics_collection_interval,
         finality_margin
       )},
      {Aggregator,
       opts: [url: url],
       contracts: contracts,
       ets: AggregatorStorage.events_bucket(),
       events: [
         [name: :deposit_created],
         [name: :in_flight_exit_started],
         [name: :in_flight_exit_input_piggybacked],
         [name: :in_flight_exit_output_piggybacked],
         [name: :exit_started]
       ]},
      Listener.prepare_child(
        ets: ListenerStorage.listener_checkin(),
        metrics_collection_interval: metrics_collection_interval,
        contract_deployment_height: contract_deployment_height,
        service_name: :depositor,
        get_events_callback: &Aggregator.deposit_created/2,
        process_events_callback: &Deposit.callback/2
      ),
      Listener.prepare_child(
        ets: ListenerStorage.listener_checkin(),
        metrics_collection_interval: metrics_collection_interval,
        contract_deployment_height: contract_deployment_height,
        service_name: :in_flight_exiter,
        get_events_callback: &Aggregator.in_flight_exit_started/2,
        process_events_callback: &InFlightExitStarted.callback/2
      ),
      Listener.prepare_child(
        ets: ListenerStorage.listener_checkin(),
        metrics_collection_interval: metrics_collection_interval,
        contract_deployment_height: contract_deployment_height,
        service_name: :piggybacker,
        get_events_callback: &Aggregator.in_flight_exit_piggybacked/2,
        process_events_callback: &Piggyback.callback/2
      ),
      Listener.prepare_child(
        ets: ListenerStorage.listener_checkin(),
        metrics_collection_interval: metrics_collection_interval,
        contract_deployment_height: contract_deployment_height,
        service_name: :standard_exiter,
        get_events_callback: &Aggregator.exit_started/2,
        process_events_callback: &ExitStarted.callback/2
      ),
      {ChildObserver, [monitor: monitor]}
    ]
  end
end
