defmodule Api.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  def start(_type, _args) do
    children = [{Plug.Cowboy, scheme: :http, plug: Api.Router, options: [port: port()]}]
    _ = Logger.info("Starting #{__MODULE__}")
    opts = [strategy: :one_for_one, name: Api.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp port, do: String.to_integer(System.get_env("PORT") || "4000")
end
