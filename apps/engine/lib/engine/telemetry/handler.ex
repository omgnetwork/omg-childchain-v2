defmodule Engine.Telemetry.Handler do
  @moduledoc """
    Telemetry handler for raising and clearing alarms, logging.
  """
  alias Status.Alert.Alarm
  require Logger

  def supported_events() do
    [
      [:monitor, :db_connection_lost, :set],
      [:monitor, :db_connection_lost, :clear],
      [:monitor, :main_ethereum_supervisor_halted, :set],
      [:monitor, :main_ethereum_supervisor_halted, :clear]
    ]
  end

  def handle_event([:monitor, :db_connection_lost, :set], %{reason: reason, timeout: timeout}, _, _config) do
    _ = Logger.error("DB supervisor crashed. Raising alarm. Reason #{inspect(reason)}. Reconnect in #{timeout}.")
    Alarm.set(Alarm.Types.db_connection_lost(__MODULE__))
  end

  def handle_event([:monitor, :db_connection_lost, :set], %{reason: :init}, _, _config) do
    _ = Logger.error("DB supervisor initializing. Raising alarm.")
    Alarm.set(Alarm.Types.db_connection_lost(__MODULE__))
  end

  def handle_event([:monitor, :db_connection_lost, :clear], _, _, _config) do
    _ = Logger.info("DB supervisor started. Clearing alarm.")
    Alarm.clear(Alarm.Types.db_connection_lost(__MODULE__))
  end

  def handle_event([:monitor, :main_ethereum_supervisor_halted, :set], %{reason: reason}, _, _config) do
    _ = Logger.error("Ethereum supervisor crashed. Raising alarm. Reason #{inspect(reason)}")
    Alarm.set(Alarm.Types.main_supervisor_halted(__MODULE__))
  end

  def handle_event([:monitor, :main_ethereum_supervisor_halted, :clear], _, _, _config) do
    _ = Logger.info("Ethereum supervisor started. Clearing alarm.")
    Alarm.clear(Alarm.Types.main_supervisor_halted(__MODULE__))
  end
end
