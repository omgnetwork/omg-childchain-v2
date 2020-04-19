defmodule Status.Alert.AlarmTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog, only: [capture_log: 1]
  alias Status.Alert.Alarm

  describe "alarm_types/0" do
    test "alarm types are correct" do
      types = Alarm.alarm_types()

      assert types ==
               Types.module_info()
               |> Keyword.fetch!(:exports)
               |> Keyword.drop([:__info__, :module_info])
    end
  end
end
