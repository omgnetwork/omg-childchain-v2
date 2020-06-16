defmodule Rpc.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  def start(_type, _args) do
    children = [{Plug.Cowboy, scheme: :http, plug: RPC.Router, options: [port: port()]}]
    _ = Logger.info("Starting #{__MODULE__}")
    opts = [strategy: :one_for_one, name: Rpc.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp port, do: (System.get_env("PORT") || "4000") |> String.to_integer()
end
