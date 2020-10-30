defmodule Engine.Application do
  @moduledoc false

  use Application

  alias Engine.Configuration
  alias Engine.Ethereum.Monitor, as: SyncMonitor
  alias Engine.Ethereum.Monitor.AlarmHandler
  alias Engine.Ethereum.Supervisor, as: EthereumSupervisor
  alias Engine.Ethereum.SyncSupervisor
  alias Engine.Plugin
  alias Engine.Repo.Monitor, as: RepoMonitor
  alias Engine.Supervisor, as: EngineSupervisor
  alias Engine.Telemetry.Handler

  require Logger

  def start(_type, _args) do
    verify_integrations()
    attach_telemetry()
    contract_deployment_height = Configuration.contract_deployment_height()
    child_args = [monitor: SyncMonitor, contract_deployment_height: contract_deployment_height]

    monitor_args = [
      name: SyncMonitor,
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
      EthereumSupervisor.child_spec([]),
      Supervisor.child_spec({SyncMonitor, monitor_args}, id: SyncMonitor),
      EngineSupervisor.child_spec([])
    ]

    _ = Logger.info("Starting #{__MODULE__}")
    opts = [strategy: :one_for_one, name: __MODULE__.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def start_phase(:boot_done, :normal, _phase_args) do
    # :ok = Alarm.clear(Alarm.boot_in_progress(__MODULE__))
    :ok
  end

  defp verify_integrations() do
    prod = Application.get_env(:engine, :prod)
    submit_block = Code.ensure_loaded?(SubmitBlock)
    gas = Code.ensure_loaded?(Gas)
    Plugin.verify(prod, submit_block, gas)
  end

  defp attach_telemetry() do
    handle_event_fun = &SpandexEcto.TelemetryAdapter.handle_event/4
    :ok = :telemetry.attach("spandex-query-tracer", [:engine, :repo, :query], handle_event_fun, nil)

    _ = Logger.info("Attaching telemetry handlers #{inspect(Handler.supported_events())}")

    case :telemetry.attach_many("alarm-handlers", Handler.supported_events(), &Handler.handle_event/4, nil) do
      :ok -> :ok
      {:error, :already_exists} -> :ok
    end
  end
end
