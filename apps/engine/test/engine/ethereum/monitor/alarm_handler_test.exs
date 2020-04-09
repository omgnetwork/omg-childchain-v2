defmodule Engine.Ethereum.Monitor.AlarmHandlerTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog, only: [capture_log: 1]
  alias Engine.Ethereum.Monitor.AlarmHandler

  test "that init creates a state" do
    assert AlarmHandler.init(consumer: :yolo) == {:ok, %AlarmHandler{consumer: :yolo}}
  end

  test "that when a clear ethereum connection error alarm arrives we send a message to the consumer" do
    clear_alarm_event = {:clear_alarm, {:ethereum_connection_error, %{}}}
    alarm_handler = %AlarmHandler{consumer: self()}

    capture_log(fn ->
      AlarmHandler.handle_event(clear_alarm_event, alarm_handler)
      assert_receive {:"$gen_cast", :start_child}
    end)
  end

  test "that when some other event arrives we ignore it (we don't receive any messages)" do
    event = {:clear_alarm, {:yolo, %{}}}
    alarm_handler = %AlarmHandler{consumer: self()}
    AlarmHandler.handle_event(event, alarm_handler)

    receive do
      _ -> assert false
    after
      100 -> assert true
    end
  end
end
