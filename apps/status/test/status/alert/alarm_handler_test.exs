defmodule Status.Alert.AlarmHandlerTest do
  use ExUnit.Case, async: true

  alias Status.Alert.Alarm
  alias Status.Alert.AlarmHandler
  alias Status.Alert.AlarmHandler.Table

  setup_all do
    {:ok, apps} = Application.ensure_all_started(:sasl)

    on_exit(fn ->
      apps |> Enum.reverse() |> Enum.each(&Application.stop/1)
    end)

    :ok = AlarmHandler.install(Alarm.alarm_types(), AlarmHandler.table_name())

    handlers = :gen_event.which_handlers(:alarm_handler)
    Enum.each(handlers -- [AlarmHandler], fn handler -> :gen_event.delete_handler(:alarm_handler, handler, []) end)
    [AlarmHandler] = :gen_event.which_handlers(:alarm_handler)
    _ = AlarmHandler.install([], AlarmHandler.table_name())
    [AlarmHandler] = :gen_event.which_handlers(:alarm_handler)
    :ok
  end

  setup %{test: test_name} do
    {:ok, state} = AlarmHandler.init(table_name: test_name, alarm_types: [test_name])
    Table.write_clear(test_name, test_name)
    %{state: state}
  end

  describe "handle_call/2" do
    test "handle call returns alarms", %{test: test_name, state: state} do
      assert({:ok, [], state1} = AlarmHandler.handle_call(:get_alarms, state))
      alarm = {test_name, %{}}
      {:ok, state2} = AlarmHandler.handle_event({:set_alarm, alarm}, state1)
      assert({:ok, [{^test_name, %{}}], ^state2} = AlarmHandler.handle_call(:get_alarms, state2))
    end
  end

  describe "handle_event/2" do
    test "update the ETS table for the raised alarm", %{test: test_name, state: state} do
      alarm = {test_name, %{}}
      {:ok, state1} = AlarmHandler.handle_event({:set_alarm, alarm}, state)
      assert 1 == Keyword.fetch!(:ets.tab2list(state.table_name), test_name)
      {:ok, state2} = AlarmHandler.handle_event({:clear_alarm, alarm}, state1)
      assert 0 == Keyword.fetch!(:ets.tab2list(state2.table_name), test_name)
    end

    test "alarm raised does nothing", %{test: test_name, state: state} do
      alarm = {test_name, %{}}
      assert 0 == Keyword.fetch!(:ets.tab2list(state.table_name), test_name)
      {:ok, state1} = AlarmHandler.handle_event({:set_alarm, alarm}, %{state | alarms: [alarm]})
      assert 0 == Keyword.fetch!(:ets.tab2list(state1.table_name), test_name)
    end
  end
end
