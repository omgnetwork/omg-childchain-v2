defmodule Engine.Ethereum.Authority.Submitter.AlarmHandler do
  @moduledoc """
  Listens for :db_connection_lost and cast the alarm back to worker
  """
  require Logger

  @type t :: %__MODULE__{consumer: module()}
  defstruct consumer: nil

  def init(args) do
    consumer = Keyword.fetch!(args, :consumer)
    {:ok, %__MODULE__{consumer: consumer}}
  end

  def handle_call(_request, state), do: {:ok, :ok, state}

  def handle_event({:set_alarm, {:db_connection_lost, _}}, state) do
    _ = Logger.warn(":db_connection_lost alarm raised.")
    :ok = GenServer.cast(state.consumer, {:set_alarm, :db_connection_lost})
    {:ok, state}
  end

  def handle_event({:clear_alarm, {:db_connection_lost, _}}, state) do
    _ = Logger.warn(":db_connection_lost alarm cleared.")
    :ok = GenServer.cast(state.consumer, {:clear_alarm, :db_connection_lost})
    {:ok, state}
  end

  def handle_event({:set_alarm, {:ethereum_connection_error, _}}, state) do
    _ = Logger.warn(":ethereum_connection_error alarm raised.")
    :ok = GenServer.cast(state.consumer, {:set_alarm, :ethereum_connection_error})
    {:ok, state}
  end

  def handle_event({:clear_alarm, {:ethereum_connection_error, _}}, state) do
    _ = Logger.warn(":ethereum_connection_error alarm cleared.")
    :ok = GenServer.cast(state.consumer, {:clear_alarm, :ethereum_connection_error})
    {:ok, state}
  end

  def handle_event(_event, state) do
    {:ok, state}
  end
end
