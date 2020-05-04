defmodule Engine.Ethereum.Event.Listener.Storage do
  @moduledoc """
  In memory storage for event listeners
  """

  @spec get_local_synced_height(atom(), atom()) :: pos_integer()
  def get_local_synced_height(key, ets) do
    case :ets.lookup(ets, key) do
      [] -> 0
      [{^key, value}] -> value
    end
  end

  @spec update_synced_height(atom(), pos_integer(), atom()) :: :ok
  def update_synced_height(key, value, ets) do
    true = :ets.insert(ets, {key, value})
    :ok
  end
end
