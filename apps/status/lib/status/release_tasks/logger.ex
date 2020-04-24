defmodule Status.ReleaseTasks.Logger do
  @moduledoc false
  @behaviour Config.Provider
  alias Status.ReleaseTasks.Validators
  require Logger

  def init(args) do
    args
  end

  def load(config, args) do
    _ = on_load(args)
    default_logger = Keyword.fetch!(args, :default_logger)
    sentry_logger = Keyword.fetch!(args, :sentry_logger)
    logger_backend = "LOGGER_BACKEND" |> get_env() |> Validators.logger(default_logger)
    _ = Logger.info("Logger setting #{logger_backend}.")
    Config.Reader.merge(config, logger: [backends: [sentry_logger, logger_backend]])
  end

  defp on_load(args) do
    adapter = Keyword.get(args, :system_adapter, System)
    _ = Process.put(:system_adapter, adapter)
  end

  @spec get_env(String.t()) :: String.t()
  defp get_env(key) do
    system_adapter().get_env(key)
  end

  defp system_adapter() do
    Process.get(:system_adapter)
  end
end
