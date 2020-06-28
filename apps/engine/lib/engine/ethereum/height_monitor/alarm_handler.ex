defmodule Engine.Ethereum.HeightMonitor.AlarmHandler do
  @moduledoc """
  Listens for :ethereum_connection_error and :ethereum_stalled_sync alarms and reflect
  the alarm's state back to the monitor.
  """
  require Logger
  @reporter Engine.Ethereum.HeightMonitor

  # The alarm reporter and monitor happen to be the same module here because we are just
  # reflecting the alarm's state back to the reporter.
  @type t :: %__MODULE__{consumer: module()}
  defstruct consumer: nil

  def init(args) do
    consumer = Keyword.fetch!(args, :consumer)
    {:ok, %__MODULE__{consumer: consumer}}
  end

  def handle_call(_request, state), do: {:ok, :ok, state}

  def handle_event({:set_alarm, {:ethereum_connection_error, %{reporter: _}}}, state) do
    _ = Logger.warn(":ethereum_connection_error alarm raised.")
    :ok = GenServer.cast(state.consumer, {:set_alarm, :ethereum_connection_error})
    {:ok, state}
  end

  def handle_event({:clear_alarm, {:ethereum_connection_error, %{reporter: _}}}, state) do
    _ = Logger.warn(":ethereum_connection_error alarm cleared.")
    :ok = GenServer.cast(state.consumer, {:clear_alarm, :ethereum_connection_error})
    {:ok, state}
  end

  def handle_event({:set_alarm, {:ethereum_stalled_sync, %{reporter: @reporter}}}, state) do
    _ = Logger.warn(":ethereum_stalled_sync alarm raised.")
    :ok = GenServer.cast(state.consumer, {:set_alarm, :ethereum_stalled_sync})
    {:ok, state}
  end

  def handle_event({:clear_alarm, {:ethereum_stalled_sync, %{reporter: @reporter}}}, state) do
    _ = Logger.warn(":ethereum_stalled_sync alarm cleared.")
    :ok = GenServer.cast(state.consumer, {:clear_alarm, :ethereum_stalled_sync})
    {:ok, state}
  end

  def handle_event(event, state) do
    _ = Logger.info("#{__MODULE__} got event: #{inspect(event)}. Ignoring.")
    {:ok, state}
  end
end
