defmodule Engine.Ethereum.Supervisor do
  @moduledoc """
   Engine Ethereum top level supervisor is supervising connection monitor towards Eth clients and
   a gen server that serves as a unified view of reported block height (`Engine.Ethereum.Height`).
  """
  use Supervisor

  alias Engine.Configuration
  alias Engine.Ethereum.Height
  alias Engine.Ethereum.HeightObserver
  alias Engine.Ethereum.RootChain.Rpc
  alias Status.Alert.Alarm
  require Logger

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    ethereum_events_check_interval_ms = Configuration.ethereum_events_check_interval_ms()
    ethereum_stalled_sync_threshold_ms = Configuration.ethereum_stalled_sync_threshold_ms()
    url = Configuration.url()

    children = [
      {Height, []},
      {HeightObserver,
       [
         name: HeightObserver,
         check_interval_ms: ethereum_events_check_interval_ms,
         stall_threshold_ms: ethereum_stalled_sync_threshold_ms,
         eth_module: Rpc,
         alarm_module: Alarm,
         event_bus_module: Bus,
         opts: [url: url]
       ]}
    ]

    opts = [strategy: :one_for_one]

    _ = Logger.info("Starting #{inspect(__MODULE__)}")
    Supervisor.init(children, opts)
  end
end
