defmodule Engine.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias Engine.Ethereum.Monitor, as: EthereumMonitor
  alias Engine.Ethereum.Monitor.AlarmHandler
  alias Engine.Ethereum.SyncSupervisor
  alias Engine.Repo.Monitor, as: RepoMonitor
  alias Engine.Telemetry.Handler

  require Logger

  def start(_type, _args) do
    attach_telemetry()
    # RootChain.get_root_deployment_height()
    {:ok, contract_deployment_height} = {:ok, 30}
    child_args = [[contract_deployment_height: contract_deployment_height]]

    monitor_args = [
      alarm_handler: AlarmHandler,
      child_spec:
        Supervisor.child_spec({SyncSupervisor, child_args},
          id: SyncSupervisor,
          restart: :permanent,
          type: :supervisor
        )
    ]

    repo_child_spec =
      Supervisor.child_spec(Engine.Repo,
        id: Engine.Repo,
        restart: :permanent,
        type: :supervisor
      )

    repo_args = [child_spec: repo_child_spec]

    children = [
      Supervisor.child_spec({RepoMonitor, repo_args}, id: RepoMonitor),
      Supervisor.child_spec({EthereumMonitor, monitor_args}, id: EthereumMonitor)
    ]

    _ = Logger.info("Starting #{__MODULE__}")
    opts = [strategy: :one_for_one, name: Engine.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def start_phase(:boot_done, :normal, _phase_args) do
    # :ok = Alarm.clear(Alarm.boot_in_progress(__MODULE__))
    :ok
  end

  defp attach_telemetry() do
    _ = Logger.info("Attaching telemetry handlers #{inspect(Handler.supported_events())}")

    case :telemetry.attach_many("alarm-handlers", Handler.supported_events(), &Handler.handle_event/4, nil) do
      :ok -> :ok
      {:error, :already_exists} -> :ok
    end
  end
end
