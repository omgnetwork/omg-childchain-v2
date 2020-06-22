defmodule Engine.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias Engine.Configuration
  alias Engine.Ethereum.Monitor, as: SyncMonitor
  alias Engine.Ethereum.Monitor.AlarmHandler
  alias Engine.Ethereum.Supervisor, as: EthereumSupervisor
  alias Engine.Ethereum.SyncSupervisor
  alias Engine.Feefeed.FeesSupervisor
  alias Engine.Repo.Monitor, as: RepoMonitor
  alias Engine.Telemetry.Handler
  alias Status.Metric.Tracer

  require Logger

  def start(_type, _args) do
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
      EthereumSupervisor.child_spec([]),
      Supervisor.child_spec({RepoMonitor, repo_args}, id: RepoMonitor),
      Supervisor.child_spec({SyncMonitor, monitor_args}, id: SyncMonitor),
      FeesSupervisor
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
    :ok =
      :telemetry.attach(
        "spandex-query-tracer",
        [:engine, :repo, :query],
        &submit_trace/4,
        nil
      )

    _ = Logger.info("Attaching telemetry handlers #{inspect(Handler.supported_events())}")

    case :telemetry.attach_many("alarm-handlers", Handler.supported_events(), &Handler.handle_event/4, nil) do
      :ok -> :ok
      {:error, :already_exists} -> :ok
    end
  end

  defp submit_trace(arg1, arg2, arg3, arg4) do
    _ = Tracer.start_trace("query")

    SpandexEcto.TelemetryAdapter.handle_event(arg1, arg2, arg3, arg4)

    _ = Tracer.finish_trace()
  end
end
