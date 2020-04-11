defmodule Engine.Ethereum.Monitor do
  @moduledoc """
  This module restarts it's children if the Ethereum client
  connectivity is dropped.
  It subscribes to alarms and when an alarm is cleared it restarts it
  children if they're dead.
  """
  use GenServer
  alias Engine.Ethereum.Monitor.Child

  require Logger

  def health_checkin() do
    GenServer.cast(__MODULE__, :health_checkin)
  end

  @type t :: %__MODULE__{alarm_module: module(), child: Child.t()}
  defstruct alarm_module: nil, child: nil

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: Keyword.get(args, :name, __MODULE__))
  end

  def init(args) when is_list(args) do
    alarm_module = Keyword.fetch!(args, :alarm)
    alarm_handler = Keyword.fetch!(args, :alarm_handler)
    child_spec = Keyword.fetch!(args, :child_spec)
    subscribe_to_alarms(alarm_handler, __MODULE__)
    Process.flag(:trap_exit, true)
    # we raise the alarms first, because we get a health checkin when all
    # sub processes of the supervisor are ready to go
    # _ = alarm_module.set(alarm_module.main_supervisor_halted(__MODULE__))
    {:ok, %__MODULE__{alarm_module: alarm_module, child: start_child(child_spec)}}
  end

  # There's a supervisor below us that did the needed restarts for it's children
  # so we do not attempt to restart the exit from the supervisor, if the alarm clears, we restart it then.
  # We declare the sytem unhealthy
  def handle_info({:EXIT, _from, reason}, state) do
    _ = Logger.error("Childchain supervisor crashed. Raising alarm. Reason #{inspect(reason)}")

    # state.alarm_module.set(state.alarm_module.main_supervisor_halted(__MODULE__))

    {:noreply, state}
  end

  # alarm has cleared, we can now begin restarting supervisor child
  def handle_cast(:health_checkin, state) do
    _ = Logger.info("Got a health checkin... clearing alarm main_supervisor_halted.")
    # _ = state.alarm_module.clear(state.alarm_module.main_supervisor_halted(__MODULE__))
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

  @spec subscribe_to_alarms(module(), module()) :: :gen_event.add_handler_ret()
  defp subscribe_to_alarms(handler, consumer) do
    case Enum.member?(:gen_event.which_handlers(:alarm_handler), handler) do
      true -> :ok
      _ -> :alarm_handler.add_alarm_handler(handler, consumer: consumer)
    end
  end
end
