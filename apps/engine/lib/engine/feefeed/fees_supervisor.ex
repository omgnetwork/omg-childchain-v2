defmodule Feefeed.FeesSupervisor do
  @moduledoc false

  use Supervisor
  alias Engine.Configuration

  alias Engine.Feefeed.Rules.Scheduler
  alias Engine.Feefeed.Rules.Worker

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, opts)
  end

  def init(_opts) do
    source_config = Configuration.source_config()
    scheduler_interval = Configuration.scheduler_interval()

    children = [
      {Worker, [name: Worker, config: source_config]},
      {Scheduler, [name: Scheduler, interval: scheduler_interval, worker_pid: Worker]}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
