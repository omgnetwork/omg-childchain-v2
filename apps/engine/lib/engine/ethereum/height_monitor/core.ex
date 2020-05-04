defmodule Engine.Ethereum.HeightMonitor.Core do
  @moduledoc """
  No idea how to name this!
  """

  alias Engine.Ethereum.HeightMonitor
  alias ExPlasma.Encoding
  require Logger

  @spec force_send_height(HeightMonitor.t()) :: HeightMonitor.t()
  def force_send_height(state) do
    height = fetch_height(state.eth_module, state.opts)
    :ok = broadcast_on_new_height(state.event_bus_module, height)
    update_height(state, height)
  end

  @spec update_height(HeightMonitor.t(), non_neg_integer() | :error) :: HeightMonitor.t()
  def update_height(state, :error), do: state

  def update_height(state, height) do
    case height > state.ethereum_height do
      true -> %{state | ethereum_height: height, synced_at: DateTime.utc_now()}
      false -> state
    end
  end

  @spec stalled?(non_neg_integer() | :error, non_neg_integer(), DateTime.t(), non_neg_integer()) :: boolean()
  def stalled?(height, previous_height, synced_at, stall_threshold_ms) do
    case height do
      height when is_integer(height) and height > previous_height ->
        false

      _ ->
        DateTime.diff(DateTime.utc_now(), synced_at, :millisecond) > stall_threshold_ms
    end
  end

  @spec fetch_height(module(), keyword()) :: non_neg_integer() | :error
  def fetch_height(eth_module, opts) do
    case eth_module.eth_block_number(opts) do
      {:ok, height} ->
        Encoding.to_int(height)

      error ->
        _ = Logger.error("Error retrieving Ethereum height: #{inspect(error)}")
        :error
    end
  end

  @spec broadcast_on_new_height(module(), non_neg_integer() | :error) :: :ok | {:error, term()}
  def broadcast_on_new_height(_event_bus_module, :error), do: :ok

  # we need to publish every height we fetched so that we can re-examine blocks in case of re-orgs
  # clients subscribed to this topic need to be aware of that and if a block number repeats,
  # it needs to re-write logs, for example
  def broadcast_on_new_height(event_bus_module, height) do
    event = Bus.Event.new({:root_chain, "ethereum_new_height"}, :ethereum_new_height, height)
    apply(event_bus_module, :broadcast, [event])
  end
end
