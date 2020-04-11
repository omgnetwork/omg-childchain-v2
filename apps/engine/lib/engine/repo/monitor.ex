defmodule Engine.Repo.Monitor do
  @moduledoc """
  This module restarts it's children if the Postgres Repo client
  connectivity is dropped.
  It tries to connect to postgres with random re-tries.
  """
  use GenServer
  alias Engine.Repo.Monitor.Child

  require Logger

  @type t :: %__MODULE__{alarm_module: module(), child: Child.t()}
  defstruct alarm_module: nil, child: nil

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: Keyword.get(args, :name, __MODULE__))
  end

  def init(args) when is_list(args) do
    alarm_module = Keyword.fetch!(args, :alarm)
    child_spec = Keyword.fetch!(args, :child_spec)
    Process.flag(:trap_exit, true)
    # we raise the alarms first, and check if PG is up
    # _ = alarm_module.set(alarm_module.database_halted(__MODULE__))
    {:ok, %__MODULE__{alarm_module: alarm_module, child: start_child(child_spec)}}
  end

  # There's a supervisor below us that did the needed restarts for it's children
  # so we do not attempt to restart the exit from the supervisor, if the alarm clears, we restart it then.
  # We declare the sytem unhealthy
  def handle_info({:EXIT, _from, reason}, state) do
    _ = Logger.error("Repo supervisor crashed. Raising alarm. Reason #{inspect(reason)}")

    # state.alarm_module.set(state.alarm_module.database_halted(__MODULE__))

    {:noreply, state}
  end

  # alarm has cleared, we can now begin restarting supervisor child
  def handle_cast(:start_child, state) do
    child = state.child
    _ = Logger.info("Monitor is restarting child #{inspect(child)}.")

    {:noreply, %{state | child: start_child(child)}}
  end

  @spec start_child(Child.t() | Supervisor.child_spec()) :: Child.t()
  defp start_child(child) do
    Child.start(child)
  end
end
