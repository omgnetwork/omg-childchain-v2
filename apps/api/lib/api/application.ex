defmodule API.Application do
  @moduledoc """
  Top level application module.
  """
  use Application

  alias API.Configuration

  def start(_type, _args) do
    children = [
      {Plug.Cowboy, scheme: :http, plug: API.Router, options: [port: 8080]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: API.Supervisor)
  end


  @spec is_disabled?() :: boolean()
  defp is_disabled?() do
    Keyword.fetch!(Configuration.tracer(), :disabled?)
  end

  defp spandex_datadog_options() do
    Configuration.spandex_datadog()
  end
end
