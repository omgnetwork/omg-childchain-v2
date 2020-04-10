defmodule Rpc.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  def start(_type, _args) do
    children = []
    _ = Logger.info("Starting #{__MODULE__}")
    opts = [strategy: :one_for_one, name: Rpc.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
