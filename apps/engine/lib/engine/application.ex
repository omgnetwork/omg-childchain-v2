defmodule Engine.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  def start(_type, _args) do
    child_args = []

    children = [
      {Engine.Repo.Monitor,
       [
         alarm: Alarm,
         child_spec: %{
           id: Engine.Repo,
           start: {Engine.Repo, :start_link, child_args},
           restart: :permanent,
           type: :worker
         }
       ]}
    ]

    _ = Logger.info("Starting #{__MODULE__}")
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Engine.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
