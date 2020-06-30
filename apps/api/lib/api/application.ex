defmodule API.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  alias API.Configuration
  require Logger

  def start(_type, _args) do
    port = Configuration.port()
    children = [{Plug.Cowboy, scheme: :http, plug: API.Router, options: [port: port]}]
    _ = Logger.info("Starting #{__MODULE__}")
    opts = [strategy: :one_for_one, name: API.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
