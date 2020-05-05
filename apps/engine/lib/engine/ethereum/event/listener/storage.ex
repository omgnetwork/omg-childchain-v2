defmodule Engine.Ethereum.Event.Listener.Storage do
  @moduledoc """
  In memory storage for event listeners
  """
  @listener_checkin :listener_checkin
  @spec listener_checkin(atom()) :: atom()
  def listener_checkin(name \\ @listener_checkin) do
    _ = if :undefined == :ets.info(name), do: :ets.new(name, [:set, :public, :named_table])
    name
  end

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
