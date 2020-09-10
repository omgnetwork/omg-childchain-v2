Mix.Task.run("ecto.drop", ~w(--quiet))
Mix.Task.run("ecto.create", ~w(--quiet))
Mix.Task.run("ecto.migrate", ~w(--quiet))
{:ok, _} = Application.ensure_all_started(:fake_server)
{:ok, _ecto} = Application.ensure_all_started(:ecto)
{:ok, _ecto_sql} = Application.ensure_all_started(:ecto_sql)
{:ok, _postgrex} = Application.ensure_all_started(:postgrex)
{:ok, _db_connection} = Application.ensure_all_started(:db_connection)
{:ok, _hackney} = Application.ensure_all_started(:hackney)
{:ok, _ex_machina} = Application.ensure_all_started(:ex_machina)
{:ok, _ethereumex} = Application.ensure_all_started(:ethereumex)
{:ok, _bus} = Application.ensure_all_started(:bus)
{:ok, _crypto} = Application.ensure_all_started(:crypto)
{:ok, _} = Engine.Repo.start_link([])
ExUnit.start(capture_log: true, assert_receive_timeout: 1000, exclude: [integration: true])
