defmodule Engine.Ethereum.Height do
  @moduledoc """
  A GenServer that subscribes to `ethereum_new_height` events coming from the internal event bus,
  decodes and saves only the height to be consumed by other services.
  """

  use GenServer
  require Logger

  @spec get() :: {:ok, non_neg_integer()} | {:error, :ethereum_height}
  def get() do
    GenServer.call(__MODULE__, :get)
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: Keyword.get(args, :name, __MODULE__))
  end

  def init(opts) do
    event_bus = Keyword.fetch!(opts, :event_bus)
    :ok = event_bus.subscribe({:root_chain, "ethereum_new_height"}, link: true)
    {:ok, {:error, :ethereum_height}}
  end

  def handle_call(:get, _from, ethereum_height) when is_number(ethereum_height) do
    {:reply, {:ok, ethereum_height}, ethereum_height}
  end

  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end

  def handle_info({:internal_event_bus, :ethereum_new_height, new_height}, _state) do
    _ = Logger.debug("Got an internal :ethereum_new_height event with height: #{new_height}.")
    {:noreply, new_height}
  end
end
