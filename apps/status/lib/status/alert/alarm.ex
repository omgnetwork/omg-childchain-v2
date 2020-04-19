defmodule Status.Alert.Alarm do
  @moduledoc """
  Interface for raising and clearing alarms related to OMG Status.
  """

  alias Status.Alert.Alarm.Types
  alias Status.Alert.AlarmHandler

  @typedoc """
  The raw alarm being used to `set` the Alarm
  """
  def alarm_types() do
    Keyword.drop(Types.module_info(:exports), [:__info__, :module_info])
  end

  @spec set(Types.alarms()) :: :ok | :duplicate
  def set(alarm), do: do_raise(alarm)

  @spec clear(Types.alarms()) :: :ok | :not_raised
  def clear(alarm), do: do_clear(alarm)

  def clear_all() do
    Enum.each(all(), &:alarm_handler.clear_alarm(&1))
  end

  def all() do
    :gen_event.call(:alarm_handler, AlarmHandler, :get_alarms)
  end

  def select(match) do
    AlarmHandler.select(match)
  end

  defp do_raise(alarm) do
    if Enum.member?(all(), alarm) do
      :duplicate
    else
      :alarm_handler.set_alarm(alarm)
    end
  end

  defp do_clear(alarm) do
    if Enum.member?(all(), alarm) do
      :alarm_handler.clear_alarm(alarm)
    else
      :not_raised
    end
  end
end
