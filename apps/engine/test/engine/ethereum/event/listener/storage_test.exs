defmodule Engine.Ethereum.Event.Listener.StorageTest do
  use ExUnit.Case, async: true

  alias Engine.Ethereum.Event.Listener.Storage

  describe "listener_chickin/0/1" do
    test "that the ets table is a set", %{test: name} do
      Storage.listener_checkin(name)
      info = :ets.info(name)
      assert Keyword.fetch!(info, :named_table) == true
      assert Keyword.fetch!(info, :type) == :set
    end
  end

  describe "get_local_synced_height/2, update_synced_height/3" do
    test "can insert and lookup", %{test: name} do
      Storage.listener_checkin(name)
      :ok = Storage.update_synced_height(:yolo, 42, name)
      42 = Storage.get_local_synced_height(:yolo, name)
      0 = Storage.get_local_synced_height(:does_not_exist, name)
    end
  end
end
