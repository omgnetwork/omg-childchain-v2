defmodule Engine.Ethereum.HeightMonitor.AlarmManagement do
  @moduledoc """
  Does all the alarm management logic from height monitoring
  """

  @spec subscribe_to_alarms(module(), module()) :: :gen_event.add_handler_ret()
  def subscribe_to_alarms(handler, consumer) do
    case Enum.member?(:gen_event.which_handlers(:alarm_handler), handler) do
      true -> :ok
      _ -> :alarm_handler.add_alarm_handler(handler, consumer: consumer)
    end
  end

  # Raise or clear the :ethereum_client_connnection alarm
  @spec connection_alarm(module(), boolean(), non_neg_integer() | :error) :: :ok | :duplicate
  def connection_alarm(alarm_module, connection_alarm_raised, raise_alarm)

  def connection_alarm(alarm_module, false, :error) do
    alarm_module.set(Module.safe_concat(alarm_module, Types).ethereum_connection_error(__MODULE__))
  end

  def connection_alarm(alarm_module, true, height) when is_integer(height) do
    alarm_module.clear(Module.safe_concat(alarm_module, Types).ethereum_connection_error(__MODULE__))
  end

  def connection_alarm(_, _, _) do
    :ok
  end

  # Raise or clear the :ethereum_stalled_sync alarm
  @spec stall_alarm(module(), boolean(), boolean()) :: :ok | :duplicate
  def stall_alarm(alarm_module, stall_alarm_raised, raise_alarm)

  def stall_alarm(alarm_module, false, true) do
    alarm_module.set(Module.safe_concat(alarm_module, Types).ethereum_stalled_sync(__MODULE__))
  end

  def stall_alarm(alarm_module, true, false) do
    alarm_module.clear(Module.safe_concat(alarm_module, Types).ethereum_stalled_sync(__MODULE__))
  end

  def stall_alarm(_alarm_module, _, _), do: :ok
end
