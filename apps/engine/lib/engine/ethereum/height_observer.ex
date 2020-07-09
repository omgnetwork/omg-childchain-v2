defmodule Engine.Ethereum.HeightObserver do
  @moduledoc """
  Periodically calls the Ethereum client node to check for Ethereumm's block height. Publishes
  internal events or raises alarms accordingly.

  When a new block height is received, it publishes an internal event under the topic `"ethereum_new_height"`
  with the payload `{:ethereum_new_height, height}`. The event is only published when the received
  block height is higher than the previously published height.

  When the call to the Ethereum client fails or returns an invalid responnse, it raises an
  `:ethereum_connection_error` alarm. The alarm is cleared once a valid block height is seen.

  When the call to the Ethereum client returns the same block height for longer than
  `:ethereum_stalled_sync_threshold_ms`, it raises an `:ethereum_stalled_sync` alarm.
  The alarm is cleared once the block height starts increasing again.
  """
  use GenServer
  use Spandex.Decorators

  alias Engine.Ethereum.HeightObserver.AlarmManagement
  alias Engine.Ethereum.HeightObserver.HeightManagement

  require Logger

  @type t() :: %__MODULE__{
          check_interval_ms: pos_integer(),
          stall_threshold_ms: pos_integer(),
          tref: reference() | nil,
          eth_module: module(),
          alarm_module: module(),
          ethereum_height: integer(),
          synced_at: DateTime.t(),
          connection_alarm_raised: boolean(),
          stall_alarm_raised: boolean(),
          bus: module(),
          opts: keyword()
        }
  @enforce_keys [
    :check_interval_ms,
    :stall_threshold_ms,
    :eth_module,
    :alarm_module,
    :synced_at,
    :connection_alarm_raised,
    :stall_alarm_raised,
    :bus,
    :opts
  ]
  defstruct check_interval_ms: 10_000,
            stall_threshold_ms: 20_000,
            tref: nil,
            eth_module: nil,
            alarm_module: nil,
            ethereum_height: 0,
            synced_at: nil,
            connection_alarm_raised: false,
            stall_alarm_raised: false,
            bus: nil,
            opts: []

  #
  # GenServer APIs
  #

  def start_link(args) do
    {server_opts, opts} = Keyword.split(args, [:name])
    GenServer.start_link(__MODULE__, opts, server_opts)
  end

  #
  # GenServer behaviors
  #

  def init(init_arg) do
    _ = Logger.info("Starting #{__MODULE__} service.")

    alarm_handler = Keyword.get(init_arg, :alarm_handler, __MODULE__.AlarmHandler)
    sasl_alarm_handler = Keyword.get(init_arg, :sasl_alarm_handler, :alarm_handler)
    :ok = AlarmManagement.subscribe_to_alarms(sasl_alarm_handler, alarm_handler, self())

    state = %__MODULE__{
      check_interval_ms: Keyword.fetch!(init_arg, :check_interval_ms),
      stall_threshold_ms: Keyword.fetch!(init_arg, :stall_threshold_ms),
      synced_at: DateTime.utc_now(),
      eth_module: Keyword.fetch!(init_arg, :eth_module),
      alarm_module: Keyword.fetch!(init_arg, :alarm_module),
      connection_alarm_raised: false,
      stall_alarm_raised: false,
      bus: Keyword.get(init_arg, :bus, Bus),
      opts: Keyword.fetch!(init_arg, :opts)
    }

    {:ok, state, {:continue, :check_new_height}}
  end

  def handle_continue(:check_new_height, state) do
    check_new_height(state)
  end

  def handle_info(:check_new_height, state) do
    check_new_height(state)
  end

  #
  # Handle incoming alarms
  #
  # These functions are called by the AlarmHandler so that this monitor process can update
  # its internal state according to the raised alarms.
  #
  def handle_cast({:set_alarm, :ethereum_connection_error}, state) do
    {:noreply, %{state | connection_alarm_raised: true}}
  end

  def handle_cast({:clear_alarm, :ethereum_connection_error}, state) do
    {:noreply, %{state | connection_alarm_raised: false}}
  end

  def handle_cast({:set_alarm, :ethereum_stalled_sync}, state) do
    {:noreply, %{state | stall_alarm_raised: true}}
  end

  def handle_cast({:clear_alarm, :ethereum_stalled_sync}, state) do
    {:noreply, %{state | stall_alarm_raised: false}}
  end

  @decorate trace(service: __MODULE__, type: :backend)
  defp check_new_height(state) do
    height = HeightManagement.fetch_height_and_publish(state)
    stalled? = HeightManagement.stalled?(height, state.ethereum_height, state.synced_at, state.stall_threshold_ms)

    _ = AlarmManagement.connection_alarm(state.alarm_module, state.connection_alarm_raised, height)
    _ = AlarmManagement.stall_alarm(state.alarm_module, state.stall_alarm_raised, stalled?)

    state = HeightManagement.update_height(state, height)
    {:ok, tref} = :timer.send_after(state.check_interval_ms, :check_new_height)
    {:noreply, %{state | tref: tref}}
  end
end
