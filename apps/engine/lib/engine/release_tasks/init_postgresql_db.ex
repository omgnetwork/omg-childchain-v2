defmodule Engine.ReleaseTasks.InitPostgresqlDB do
  @moduledoc false
  require Logger
  @app :engine

  def migrate() do
    Logger.info("Starting migration.")
    Process.flag(:trap_exit, true)
    do_migrate()
    Process.flag(:trap_exit, false)
    Logger.info("Migration done.")
  end

  def rollback(repo, version) do
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos() do
    _ = Application.load(@app)
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp do_migrate() do
    parent = self()
    repos = repos()

    for repo <- repos do
      spawn_link(fn ->
        Logger.info("Engine: #{inspect(Application.get_all_env(:engine))}")
        _ = Application.put_env(@app, repo, url: System.get_env("DATABASE_URL"))
        Logger.info("Engine: #{inspect(Application.get_all_env(:engine))}")
        {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
        Kernel.send(parent, {:done, repo})
      end)
    end

    result_or_wait(repos)
  end

  defp result_or_wait([]) do
    :done
  end

  defp result_or_wait(repos) do
    receive do
      {:EXIT, _, :shutdown} ->
        _ = Logger.error("Can't run migration. Will wait.")
        result_or_wait(repos)

      {:done, repo} ->
        _ = Logger.info("Migration for #{repo} done. Remaining: #{inspect(repos -- [repo])}")
        result_or_wait(repos -- [repo])
    after
      10_000 ->
        do_migrate()
    end
  end
end
