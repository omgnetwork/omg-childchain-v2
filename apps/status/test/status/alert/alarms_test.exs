defmodule Status.Alert.AlarmTest do
  use ExUnit.Case, async: false
  alias Status.Alert.Alarm
  alias Status.Alert.Alarm.Types

  setup_all do
    {:ok, apps} = Application.ensure_all_started(:status)

    on_exit(fn ->
      apps |> Enum.reverse() |> Enum.each(&Application.stop/1)
    end)

    :ok
  end

  setup do
    Alarm.clear_all()
  end

  describe "alarm_types/0" do
    test "alarm types are correct" do
      types = Alarm.alarm_types()

      assert types ==
               Types.module_info()
               |> Keyword.fetch!(:exports)
               |> Keyword.drop([:__info__, :module_info])
    end
  end

  test "raise and clear alarm based only on id" do
    alarm = {:id, "details"}
    :alarm_handler.set_alarm(alarm)
    assert get_alarms([:id]) == [alarm]
    :alarm_handler.clear_alarm(alarm)
    assert get_alarms([:id]) == []
  end

  test "raise and clear alarm based on full alarm" do
    alarm = {:id5, %{a: 12, b: 34}}
    :alarm_handler.set_alarm(alarm)
    assert get_alarms([:id5]) == [alarm]
    :alarm_handler.clear_alarm({:id5, %{a: 12, b: 666}})
    assert get_alarms([:id5]) == [alarm]
    :alarm_handler.clear_alarm(alarm)
    assert get_alarms([:id5]) == []
  end

  test "adds and removes alarms" do
    # we *do* (unifying them under one app) want system alarms (like CPU, memory...)
    :alarm_handler.set_alarm({:some_system_alarm, "description_1"})
    assert not Enum.empty?(get_alarms([:some_system_alarm]))
    Alarm.clear_all()
    Alarm.set(Types.ethereum_connection_error(__MODULE__))
    assert Enum.count(get_alarms([:some_system_alarm, :ethereum_connection_error])) == 1

    Alarm.set(Types.ethereum_connection_error(__MODULE__.SecondProcess))
    assert Enum.count(get_alarms([:some_system_alarm, :ethereum_connection_error])) == 2

    Alarm.clear(Types.ethereum_connection_error(__MODULE__))
    assert Enum.count(get_alarms([:some_system_alarm, :ethereum_connection_error])) == 1

    Alarm.clear_all()
    assert Enum.empty?(get_alarms([:some_system_alarm, :ethereum_connection_error])) == true
  end

  test "an alarm raise twice is reported once" do
    Alarm.set(Types.ethereum_connection_error(__MODULE__))
    first_count = Enum.count(get_alarms([:ethereum_connection_error]))
    Alarm.set(Types.ethereum_connection_error(__MODULE__))
    ^first_count = Enum.count(get_alarms([:ethereum_connection_error]))
  end

  test "memsup alarms" do
    # memsup set alarm
    :alarm_handler.set_alarm({:system_memory_high_watermark, []})

    assert Enum.any?(Alarm.all(), &(elem(&1, 0) == :system_memory_high_watermark))
  end

  # we need to filter them because of unwanted system alarms, like high memory threshold
  # so we send the alarms we want to find in the args
  defp get_alarms(ids), do: Enum.filter(Alarm.all(), fn {id, _desc} -> id in ids end)
end
