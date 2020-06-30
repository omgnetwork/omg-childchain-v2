defmodule Engine.Ethereum.HeightObserver.HeightManagement do
  @moduledoc """
  No idea how to name this!
  """

  alias Engine.Ethereum.HeightObserver
  alias ExPlasma.Encoding
  require Logger

  @spec update_height(HeightObserver.t(), non_neg_integer() | :error) :: HeightObserver.t()
  def update_height(state, :error) do
    state
  end

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

  @spec fetch_height_and_publish(HeightObserver.t()) :: non_neg_integer() | :error
  def fetch_height_and_publish(state) do
    state.opts
    |> state.eth_module.eth_block_number()
    |> case do
      {:ok, height} ->
        height = Encoding.to_int(height)
        :ok = broadcast_on_new_height(height)
        height

      error ->
        _ = Logger.error("Error retrieving Ethereum height: #{inspect(error)}")
        :error
    end
  end

  # we need to publish every height we fetched so that we can re-examine blocks in case of re-orgs
  # clients subscribed to this topic need to be aware of that and if a block number repeats,
  # it needs to re-write logs, for example
  defp broadcast_on_new_height(height) do
    event = Bus.Event.new({:root_chain, "ethereum_new_height"}, :ethereum_new_height, height)
    Bus.local_broadcast(event)
  end
end
