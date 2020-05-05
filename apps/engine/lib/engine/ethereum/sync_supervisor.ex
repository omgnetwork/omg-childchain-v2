defmodule Engine.Ethereum.SyncSupervisor do
  @moduledoc """
   Ethereum listeners top level supervisor.
  """
  use Supervisor

  alias Engine.Callbacks.Deposit
  alias Engine.Configuration
  alias Engine.Ethereum.ChildObserver
  alias Engine.Ethereum.Event.Aggregator
  alias Engine.Ethereum.Event.Aggregator.Storage, as: AggregatorStorage
  alias Engine.Ethereum.Event.Listener
  alias Engine.Ethereum.Event.Listener.Storage, as: ListenerStorage
  alias Engine.Ethereum.Event.RootChainCoordinator
  alias Engine.Ethereum.Event.RootChainCoordinator.Setup

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
    deposit_finality_margin = Configuration.deposit_finality_margin()
    metrics_collection_interval = Configuration.metrics_collection_interval()
    coordinator_eth_height_check_interval_ms = Configuration.coordinator_eth_height_check_interval_ms()
    contracts = Configuration.contracts()
    url = Configuration.url()

    [
      {RootChainCoordinator,
       Setup.coordinator_setup(
         metrics_collection_interval,
         coordinator_eth_height_check_interval_ms,
         deposit_finality_margin
       )},
      {Aggregator,
       opts: [url: url],
       contracts: contracts,
       ets: AggregatorStorage.events_bucket(),
       events: [
         [name: :deposit_created, enrich: false],
         [name: :in_flight_exit_started, enrich: true],
         [name: :in_flight_exit_input_piggybacked, enrich: false],
         [name: :in_flight_exit_output_piggybacked, enrich: false],
         [name: :exit_started, enrich: true]
       ]},
      Listener.prepare_child(
        ets: ListenerStorage.listener_checkin(),
        metrics_collection_interval: metrics_collection_interval,
        contract_deployment_height: contract_deployment_height,
        service_name: :depositor,
        get_events_callback: &Aggregator.deposit_created/2,
        process_events_callback: &Deposit.callback/2
      ),
      # EthereumEventListener.prepare_child(
      #   ets: ListenerStorage.listener_checkin(),
      #   metrics_collection_interval: metrics_collection_interval,
      #   ethereum_events_check_interval_ms: ethereum_events_check_interval_ms,
      #   contract_deployment_height: contract_deployment_height,
      #   service_name: :in_flight_exit,
      #   get_events_callback: &Aggregator.in_flight_exit_started/2,
      #   process_events_callback: &exit_and_ignore_validities/1
      # ),
      # EthereumEventListener.prepare_child(
      #   ets: ListenerStorage.listener_checkin(),
      #   metrics_collection_interval: metrics_collection_interval,
      #   ethereum_events_check_interval_ms: ethereum_events_check_interval_ms,
      #   contract_deployment_height: contract_deployment_height,
      #   service_name: :piggyback,
      #   get_events_callback: &Aggregator.in_flight_exit_piggybacked/2,
      #   process_events_callback: &exit_and_ignore_validities/1
      # ),
      # EthereumEventListener.prepare_child(
      #   ets: ListenerStorage.listener_checkin(),
      #   metrics_collection_interval: metrics_collection_interval,
      #   ethereum_events_check_interval_ms: ethereum_events_check_interval_ms,
      #   contract_deployment_height: contract_deployment_height,
      #   service_name: :exiter,
      #   get_events_callback: &Aggregator.exit_started/2,
      #   process_events_callback: &exit_and_ignore_validities/1
      # ),
      {ChildObserver, [monitor: monitor]}
    ]
  end
end
