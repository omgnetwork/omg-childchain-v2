defmodule Feefeed.FeesSupervisor do
  @moduledoc false

  use Supervisor
  alias Engine.Configuration
  alias Engine.Feefeed.Fees.Orchestrator
  alias Engine.Feefeed.Rules.Scheduler
  alias Engine.Feefeed.Rules.Source
  alias Engine.Feefeed.Rules.Worker

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    scheduler_interval = Configuration.scheduler_interval()
    source_config = Configuration.source_config()

    children = [
      {Orchestrator, []},
      {Worker, [name: Worker, source_pid: Source, orchestrator_pid: Orchestrator]},
      {Source, [name: Source, config: source_config]},
      {Scheduler, [name: Scheduler, interval: scheduler_interval, worker_pid: Worker]}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
