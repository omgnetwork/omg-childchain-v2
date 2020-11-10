Mix.Task.run("ecto.drop", ~w(--quiet))
Mix.Task.run("ecto.create", ~w(--quiet))
Mix.Task.run("ecto.migrate", ~w(--quiet))
{:ok, _} = Application.ensure_all_started(:fake_server)
{:ok, _hackney} = Application.ensure_all_started(:hackney)
{:ok, _ex_machina} = Application.ensure_all_started(:ex_machina)
{:ok, _ethereumex} = Application.ensure_all_started(:ethereumex)
{:ok, _bus} = Application.ensure_all_started(:bus)
{:ok, _} = Engine.Repo.start_link([])
ExUnit.start(capture_log: true, assert_receive_timeout: 1000, exclude: [integration: true])

# this is needed for health plug
{:ok, _} = Application.ensure_all_started(:sasl)
:ok = Status.Alert.AlarmHandler.install(Status.Alert.Alarm.alarm_types(), Status.Alert.AlarmHandler.table_name())
