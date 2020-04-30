defmodule Engine.Ethereum.SyncSupervisor do
  @moduledoc """
   Ethereum listeners top level supervisor.
  """
  use Supervisor
  alias Engine.Configuration
  alias Engine.Ethereum.Event.Aggregator
  alias Engine.Ethereum.RootChainCoordinator
  alias Engine.Ethereum.RootChainCoordinator.Setup
  require Logger

  @events_bucket :events_bucket

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    opts = [strategy: :one_for_one]

    _ = Logger.info("Starting #{__MODULE__}")
    :ok = ensure_ets_init()
    children = children()
    Supervisor.init(children, opts)
  end

  defp children() do
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
       ets_bucket: @events_bucket,
       events: [
         [name: :deposit_created, enrich: false],
         [name: :in_flight_exit_started, enrich: true],
         [name: :in_flight_exit_input_piggybacked, enrich: false],
         [name: :in_flight_exit_output_piggybacked, enrich: false],
         [name: :exit_started, enrich: true]
       ]}
    ]
  end

  defp ensure_ets_init() do
    _ = if :undefined == :ets.info(@events_bucket), do: :ets.new(@events_bucket, [:bag, :public, :named_table])
    :ok
  end
end
