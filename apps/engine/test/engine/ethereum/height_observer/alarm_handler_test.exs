defmodule Engine.Ethereum.HeightObserver.AlarmHandlerTest do
  use ExUnit.Case, async: true
  alias Engine.Ethereum.HeightObserver.AlarmHandler
  alias Engine.Ethereum.HeightObserver.AlarmManagement

  setup do
    {:ok, state} = AlarmHandler.init(consumer: self())
    Map.from_struct(state)
  end

  test "raised alarm is sent to the consumer", %{consumer: consumer} do
    AlarmHandler.handle_event({:set_alarm, {:ethereum_connection_error, %{reporter: AlarmManagement}}}, %{consumer: consumer})
    assert_receive {:"$gen_cast", {:set_alarm, :ethereum_connection_error}}
    AlarmHandler.handle_event({:set_alarm, {:ethereum_stalled_sync, %{reporter: AlarmManagement}}}, %{consumer: consumer})
    assert_receive {:"$gen_cast", {:set_alarm, :ethereum_stalled_sync}}
  end

  test "cleared alarm is sent to the consumer", %{consumer: consumer} do
    AlarmHandler.handle_event({:clear_alarm, {:ethereum_connection_error, %{reporter: AlarmManagement}}}, %{consumer: consumer})

    assert_receive {:"$gen_cast", {:clear_alarm, :ethereum_connection_error}}
    AlarmHandler.handle_event({:clear_alarm, {:ethereum_stalled_sync, %{reporter: AlarmManagement}}}, %{consumer: consumer})
    assert_receive {:"$gen_cast", {:clear_alarm, :ethereum_stalled_sync}}
  end

  test "all other alarms are ignored", %{consumer: consumer} do
    AlarmHandler.handle_event({:clear_alarm, {:yolo1, %{reporter: AlarmManagement}}}, %{consumer: consumer})
    refute_receive {:"$gen_cast", {:clear_alarm, :yolo1}}
  end
end
