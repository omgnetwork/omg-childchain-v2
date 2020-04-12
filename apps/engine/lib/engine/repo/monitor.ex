defmodule Engine.Repo.Monitor do
  @moduledoc """
  This module restarts it's children if the Postgres Repo client
  connectivity is dropped.
  It tries to connect to postgres with random re-tries.
  """
  use GenServer
  alias DBConnection.Backoff
  alias Engine.Repo.Monitor.Child

  require Logger

  @type t :: %__MODULE__{
          alarm_module: module(),
          child: Child.t(),
          backoff: map()
        }
  defstruct alarm_module: nil,
            child: nil,
            backoff: nil

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: Keyword.get(args, :name, __MODULE__))
  end

  def init(args) do
    alarm_module = Keyword.fetch!(args, :alarm)
    child_spec = Keyword.fetch!(args, :child_spec)
    Process.flag(:trap_exit, true)
    # we raise the alarms first, and check if PG is up
    # _ = alarm_module.set(alarm_module.db_connection_lost(__MODULE__))
    _ = Logger.info("Starting #{__MODULE__} with child #{child_spec.id}")
    # @default_type :rand_exp
    # @min          1_000
    # @max          30_000
    # configure this by sending backoff_min or backoff_max
    backoff = Backoff.new(args)
    child = start_child(child_spec)

    {:ok, %__MODULE__{backoff: backoff, alarm_module: alarm_module, child: child}}
  end

  def handle_info({:timeout, _crash_recover_timer, :crash_recover}, state) do
    _ =
      case Process.alive?(state.child.pid) do
        true ->
          Logger.info("DB supervisor back. Clearing alarm.")

        _ ->
          :ok
      end

    {:noreply, state}
  end

  def handle_info({:timeout, _restart_timer, :restart}, state) do
    child = start_child(state.child)
    {:noreply, %{state| child: child}}
  end

  # There's a supervisor below us that did the needed restarts for it's children
  # so we do not attempt to restart the exit from the supervisor, if the alarm clears, we restart it then.
  # We declare the sytem unhealthy
  def handle_info({:EXIT, _from, reason}, state) do
    {timeout, backoff} = Backoff.backoff(state.backoff)
    _restart_timer = start_timer(timeout, :restart)
    _crash_recover_timer = start_timer(timeout + 1000, :crash_recover)
    _ = Logger.error("DB supervisor crashed. Raising alarm. Reason #{inspect(reason)}. Reconnect in #{timeout}.")

    # state.alarm_module.set(state.alarm_module.db_connection_lost(__MODULE__))
    {:noreply, %{state | backoff: backoff}}
  end

  @spec start_child(Child.t() | Supervisor.child_spec()) :: Child.t()
  defp start_child(child) do
    Child.start(child)
  end

  defp start_timer(timeout, msg) do
    :erlang.start_timer(timeout, self(), msg)
  end
end
