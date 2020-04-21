defmodule Status.ReleaseTasks.Validators do
  @moduledoc false
  @spec url(String.t()) :: false | String.t()
  def url(url) when is_binary(url) and byte_size(url) > 0 do
    uri = URI.parse(url)

    case uri.scheme != nil && uri.host |> String.to_charlist() |> :inet_parse.domain() do
      true -> url
      _ -> false
    end
  end

  def url(_) do
    false
  end

  def app_env(app_env, included_environments) do
    app_env in included_environments
  end

  def logger(logger, default_logger) when is_binary(logger) and byte_size(logger) > 0 do
    do_validate_logger(String.upcase(logger), default_logger)
  end

  def logger(_logger, default_logger) do
    default_logger
  end

  defp do_validate_logger("CONSOLE", _), do: :console
  defp do_validate_logger(_, default_logger), do: default_logger
end
