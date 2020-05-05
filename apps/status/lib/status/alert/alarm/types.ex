defmodule Status.Alert.Alarm.Types do
  @moduledoc false

  @type alarm_detail :: %{
          node: Node.t(),
          reporter: module()
        }

  @typedoc """
  The raw alarm being used to `set` the Alarm
  """
  @type alarms ::
          {:boot_in_progress
           | :db_connection_lost
           | :ethereum_connection_error
           | :ethereum_stalled_sync
           | :invalid_fee_source
           | :main_supervisor_halted, alarm_detail}

  @spec db_connection_lost(module()) :: {:db_connection_lost, alarm_detail}
  def db_connection_lost(reporter) do
    {:db_connection_lost, %{node: Node.self(), reporter: reporter}}
  end

  @spec ethereum_connection_error(module()) :: {:ethereum_connection_error, alarm_detail}
  def ethereum_connection_error(reporter) do
    {:ethereum_connection_error, %{node: Node.self(), reporter: reporter}}
  end

  @spec ethereum_stalled_sync(module()) :: {:ethereum_stalled_sync, alarm_detail}
  def ethereum_stalled_sync(reporter) do
    {:ethereum_stalled_sync, %{node: Node.self(), reporter: reporter}}
  end

  @spec boot_in_progress(module()) :: {:boot_in_progress, alarm_detail}
  def boot_in_progress(reporter) do
    {:boot_in_progress, %{node: Node.self(), reporter: reporter}}
  end

  @spec invalid_fee_source(module()) :: {:invalid_fee_source, alarm_detail}
  def invalid_fee_source(reporter) do
    {:invalid_fee_source, %{node: Node.self(), reporter: reporter}}
  end

  @spec main_supervisor_halted(module()) :: {:main_supervisor_halted, alarm_detail}
  def main_supervisor_halted(reporter) do
    {:main_supervisor_halted, %{node: Node.self(), reporter: reporter}}
  end
end
