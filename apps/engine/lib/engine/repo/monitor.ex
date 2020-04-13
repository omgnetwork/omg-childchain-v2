defmodule Engine.Repo.Monitor do
  @moduledoc """
  This module restarts it's children if the Postgres Repo client
  connectivity is dropped.
  It tries to connect to postgres with random re-tries.
  Backoff can be tuned by passing:
   @default_type :rand_exp
   @min          1_000
   @max          30_000
   configure this by sending backoff_min or backoff_max
  Read more: DBConnection.Backoff
  """
  use GenServer
  alias DBConnection.Backoff
  alias Engine.Repo.Monitor.Child

  require Logger

  def handle_event([:ecto, :repo, :init], _, _, %{monitor: monitor}) do
    GenServer.cast(monitor, :ack)
  end

  @type t :: %__MODULE__{
          child: Child.t(),
          backoff: map(),
          health_check_after_crash: non_neg_integer()
        }
  defstruct [:child, :backoff, :health_check_after_crash]

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: Keyword.get(args, :name, __MODULE__))
  end

  def init(opts) do
    {backoff, opts} = Keyword.split(opts, [:backoff_min, :backoff_max, :type])
    child_spec = Keyword.fetch!(opts, :child_spec)
    name = Keyword.get(opts, :name, __MODULE__)
    health_check_after_crash = Keyword.get(opts, :health_check_after_crash, 1000)
    Process.flag(:trap_exit, true)
    :ok = :telemetry.execute([:monitor, :db_connection_lost, :set], %{reason: :init}, %{})
    :ok = :telemetry.attach("repo-init-#{name}", [:ecto, :repo, :init], &handle_event/4, %{monitor: self()})
    _ = Logger.info("Starting #{__MODULE__} with child #{child_spec.id}")
    backoff_state = Backoff.new(backoff)
    child = start_child(child_spec)
    {:ok, %__MODULE__{child: child, backoff: backoff_state, health_check_after_crash: health_check_after_crash}}
  end

  def handle_cast(:ack, state) do
    {:noreply, state, state.health_check_after_crash}
  end

  def handle_info(:timeout, state) do
    case Process.alive?(state.child.pid) do
      true ->
        :ok = :telemetry.execute([:monitor, :db_connection_lost, :clear], %{}, %{})
        backoff = Backoff.reset(state.backoff)
        {:noreply, %{state | backoff: backoff}}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info({:timeout, _restart_timer, :restart}, state) do
    child = start_child(state.child)
    {:noreply, %{state | child: child}}
  end

  # There's a supervisor below us that did the needed restarts for it's children
  # so we do not attempt to restart the exit from the supervisor, if the alarm clears, we restart it then.
  # We declare the sytem unhealthy
  def handle_info({:EXIT, _from, reason}, state) do
    {timeout, backoff} = Backoff.backoff(state.backoff)
    _restart_timer = start_timer(timeout, :restart)
    :ok = :telemetry.execute([:monitor, :db_connection_lost, :set], %{reason: reason, timeout: timeout}, %{})
    {:noreply, %{state | backoff: backoff}}
  end

  def terminate(_reason, _state) do
    {:registered_name, name} = Process.info(self(), :registered_name)
    :telemetry.detach("repo-init-#{name}")
  end

  @spec start_child(Child.t() | Supervisor.child_spec()) :: Child.t()
  defp start_child(child) do
    Child.start(child)
  end

  defp start_timer(timeout, msg) do
    :erlang.start_timer(timeout, self(), msg)
  end
end
