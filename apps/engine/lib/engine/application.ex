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
  alias Engine.Repo.Monitor, as: RepoMonitor
  alias Engine.Supervisor, as: EngineSupervisor
  alias Engine.Telemetry.Handler

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

  def start_phase(:verify_integrations, :normal, _phase_args) do
    prod = Application.get_env(:engine, :prod)
    enterprise = Application.get_env(:engine, :enterprise)

    case {prod, enterprise} do
      {true, "0"} ->
        true = Code.ensure_loaded?(SubmitBlock)

        ast =
          quote do
            def unquote(:gas)(), do: unquote(100_000)
          end

        Module.create(Gas, ast, Macro.Env.location(__ENV__))
          :ok
      {true, "1"} ->
        true = Code.ensure_loaded?(SubmitBlock)
        true = Code.ensure_loaded?(Gas)
        _ = Logger.error("You're in DEV mode. You don't have any integrations loaded. This isn't what you want. Probably.")
        :ok
      {nil, _} ->
        _ = Logger.error("You're in DEV or TEST mode. You don't have any integrations loaded. This isn't what you want. Probably.")
        :ok
    end
  end

  defp attach_telemetry() do
    :ok =
      :telemetry.attach(
        "spandex-query-tracer",
        [:engine, :repo, :query],
        &SpandexEcto.TelemetryAdapter.handle_event/4,
        nil
      )

    _ = Logger.info("Attaching telemetry handlers #{inspect(Handler.supported_events())}")

    case :telemetry.attach_many("alarm-handlers", Handler.supported_events(), &Handler.handle_event/4, nil) do
      :ok -> :ok
      {:error, :already_exists} -> :ok
    end
  end
end
