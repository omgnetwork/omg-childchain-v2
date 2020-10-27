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

  def verify_integrations() do
    prod = Application.get_env(:engine, :prod)

    case {prod, Code.ensure_loaded?(SubmitBlock), Code.ensure_loaded?(Gas)} do
      {true, true, false} ->
        true = Code.ensure_loaded?(SubmitBlock)

        create_gas()
        message = "You're in PROD mode. Default Gas module created. SubmitBlock loaded."
        _ = Logger.info(message)
        :ok

      {true, true, true} ->
        true = Code.ensure_loaded?(SubmitBlock)
        true = Code.ensure_loaded?(Gas)
        message = "You're in PROD ENTERPRISE mode. Integrations are loaded."
        _ = Logger.info(message)

        :ok

      {true, _, _} ->
        message =
          "You're in PROD mode. You don't have all integrations loaded. This isn't what you want. I'll halt the VM."

        _ = Logger.error(message)
        message |> String.to_charlist() |> :erlang.halt()

      _ ->
        message =
          "You're in DEV or TEST mode. You don't have any integrations loaded. This isn't what you want. Probably."

        _ = Logger.error(message)

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

  defp create_gas() do
    ast =
      quote do
        defmodule unquote(Gas) do
          defstruct low: 70_000 * 60 / 100, fast: 80_000, fastest: 120_000, standard: 70_000, name: "Geth"
          def unquote(:gas)(_), do: "Elixir.Gas" |> String.to_atom() |> Kernel.struct!()
          def unquote(:integrations)(), do: []
        end
      end

    {{:module, Gas, _, _}, []} = Code.eval_quoted(ast)
    true = Code.ensure_loaded?(Gas)
  end
end
