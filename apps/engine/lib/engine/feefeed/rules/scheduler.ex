defmodule Engine.Feefeed.Rules.Scheduler do
  @moduledoc """
  This GenServer is a ticking machine, sending :update
  to all linked process every X seconds.
  """

  use GenServer
  alias Engine.Feefeed.Rules.Worker

  require Logger

  @type scheduler_state_t() :: %{
          interval: pos_integer(),
          worker_pid: pid()
        }

  @doc """
  Starts the server with the given options.
  """
  @spec start_link(interval: pos_integer(), worker_pid: pid()) :: {:ok, pid()}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, opts)
  end

  @impl true
  @spec init(interval: pos_integer(), worker_pid: pid()) ::
          {:ok, scheduler_state_t(), {:continue, :start_ticking}}
  def init(opts) do
    _ = Logger.info("Starting #{__MODULE__}")

    {:ok, %{interval: opts[:interval], worker_pid: opts[:worker_pid]}, {:continue, :start_ticking}}
  end

  ## Callbacks
  ##

  @impl true
  @spec handle_continue(:start_ticking, scheduler_state_t()) ::
          {:noreply, scheduler_state_t()}
  def handle_continue(:start_ticking, state) do
    tick(state)
    {:noreply, state}
  end

  @impl true
  @spec handle_info(:process, scheduler_state_t()) ::
          {:noreply, map()}
  def handle_info(:process, state) do
    _ = Logger.info("Reached rules update schedule.")

    :ok = Worker.update(state.worker_pid)

    tick(state)
    {:noreply, state}
  end

  defp tick(state) do
    _ = Logger.info("Scheduling rules update in #{state.interval} s")
    Process.send_after(self(), :process, state.interval * 1000)
  end
end
