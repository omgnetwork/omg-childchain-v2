defmodule Status.ReleaseTasks.Sentry do
  @moduledoc false

  @behaviour Config.Provider
  alias Status.ReleaseTasks.Validators
  require Logger

  def init(args) do
    args
  end

  # remember, release tasks run AFTER release.exs gets evaluated.
  def load(config, args) do
    _ = on_load(args)
    current_version = Keyword.fetch!(args, :current_version)
    sentry_dsn = "SENTRY_DSN" |> get_env() |> Validators.url()
    hostname = "HOSTNAME" |> get_env() |> Validators.url()
    included_environments = config |> Keyword.fetch!(:sentry) |> Keyword.fetch!(:included_environments)
    app_env = "APP_ENV" |> get_env() |> Validators.app_env(included_environments)

    _ =
      case {is_binary(sentry_dsn), is_binary(app_env), is_binary(hostname)} do
        {true, true, true} ->
          :ok

        _ ->
          log =
            "If you want Sentry enabled set " <>
              "SENTRY_DSN, HOSTNAME and APP_ENV #{inspect(included_environments)}."

          Logger.warn(log)
      end

    tags =
      config
      |> Keyword.fetch!(:sentry)
      |> Keyword.fetch!(:tags)
      |> Map.merge(%{current_version: "vsn-#{current_version}"})

    Config.Reader.merge(config, sentry: [tags: tags])
  end

  @spec get_env(String.t()) :: String.t()
  defp get_env(key) do
    system_adapter().get_env(key)
  end

  defp system_adapter() do
    Process.get(:system_adapter)
  end

  defp on_load(args) do
    adapter = Keyword.get(args, :system_adapter, System)
    _ = Process.put(:system_adapter, adapter)
    _ = Application.ensure_all_started(:logger)
  end
end
