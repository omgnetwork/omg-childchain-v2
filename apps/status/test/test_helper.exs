# this is needed for health plug
{:ok, _} = Application.ensure_all_started(:sasl)
:ok = Status.Alert.AlarmHandler.install(Status.Alert.Alarm.alarm_types(), Status.Alert.AlarmHandler.table_name())

ExUnit.start(capture_log: true)
