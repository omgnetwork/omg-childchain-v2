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

  @type t :: %__MODULE__{child: Child.t()}
  defstruct child: nil

  def start_link(args) do
    {server_opts, opts} = Keyword.split(args, [:name])
    GenServer.start_link(__MODULE__, opts, server_opts)
  end

  def init(opts) do
    alarm_handler = Keyword.fetch!(opts, :alarm_handler)
    child_spec = Keyword.fetch!(opts, :child_spec)
    subscribe_to_alarms(alarm_handler, __MODULE__)
    Process.flag(:trap_exit, true)
    # we raise the alarms first, because we get a health checkin when all
    # sub processes of the supervisor are ready to go
    :telemetry.execute([:monitor, :main_ethereum_supervisor_halted, :set], %{reason: :init}, %{})
    _ = Logger.info("Starting #{__MODULE__} with child #{child_spec.id}")
    {:ok, %__MODULE__{child: start_child(child_spec)}}
  end

  # There's a supervisor below us that did the needed restarts for it's children
  # so we do not attempt to restart the exit from the supervisor, if the alarm clears, we restart it then.
  # We declare the sytem unhealthy
  def handle_info({:EXIT, _from, reason}, state) do
    :telemetry.execute([:monitor, :main_ethereum_supervisor_halted, :set], %{reason: reason}, %{})

    {:noreply, state}
  end

  # alarm has cleared, we can now begin restarting supervisor child
  def handle_cast(:health_checkin, state) do
    :telemetry.execute([:monitor, :main_ethereum_supervisor_halted, :clear], %{}, %{})
    {:noreply, state}
  end

  # alarm has cleared, we can now begin restarting supervisor child
  def handle_cast(:start_child, state) do
    child = state.child
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
