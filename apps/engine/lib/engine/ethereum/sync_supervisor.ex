defmodule Engine.Ethereum.SyncSupervisor do
  @moduledoc """
   Ethereum listeners top level supervisor.
  """
  use Supervisor

  alias Engine.Callbacks.Deposit
  alias Engine.Configuration
  alias Engine.Ethereum.ChildObserver
  alias Engine.Ethereum.Event.Aggregator
  alias Engine.Ethereum.Event.EventListener
  alias Engine.Ethereum.Event.RootChainCoordinator
  alias Engine.Ethereum.Event.RootChainCoordinator.Setup

  require Logger

  @events_bucket :events_bucket
  @listener_checkin :listener_checkin

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    opts = [strategy: :one_for_one]

    _ = Logger.info("Starting #{__MODULE__}")
    :ok = ensure_ets_init()
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
       ets: @events_bucket,
       events: [
         [name: :deposit_created, enrich: false],
         [name: :in_flight_exit_started, enrich: true],
         [name: :in_flight_exit_input_piggybacked, enrich: false],
         [name: :in_flight_exit_output_piggybacked, enrich: false],
         [name: :exit_started, enrich: true]
       ]},
      EventListener.prepare_child(
        ets: @listener_checkin,
        metrics_collection_interval: metrics_collection_interval,
        contract_deployment_height: contract_deployment_height,
        service_name: :depositor,
        get_events_callback: &Aggregator.deposit_created/2,
        process_events_callback: &Deposit.callback/2
      ),
      {ChildObserver, [monitor: monitor]}
    ]
  end

  defp ensure_ets_init() do
    _ = if :undefined == :ets.info(@events_bucket), do: :ets.new(@events_bucket, [:bag, :public, :named_table])
    _ = if :undefined == :ets.info(@listener_checkin), do: :ets.new(@listener_checkin, [:set, :public, :named_table])
    :ok
  end
end
