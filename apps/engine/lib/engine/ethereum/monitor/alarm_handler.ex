defmodule Engine.Ethereum.Monitor.AlarmHandler do
  @moduledoc """
    State of the Gen Event alarm handler https://erlang.org/doc/man/alarm_handler.html
  """
  require Logger

  @type t :: %__MODULE__{consumer: module()}
  defstruct consumer: nil

  @doc """
  Gen Event alarm handler init
  """
  def init(args) do
    consumer = Keyword.fetch!(args, :consumer)
    {:ok, %__MODULE__{consumer: consumer}}
  end

  def handle_event({:clear_alarm, {:ethereum_connection_error, _}}, state) do
    alarm = :ethereum_connection_error
    _ = Logger.warn("#{alarm} alarm was cleared. Beginning to restart processes.")

    :ok = GenServer.cast(state.consumer, :start_child)
    {:ok, state}
  end

  # flush
  def handle_event(event, state) do
    {:ok, state}
  end
end
