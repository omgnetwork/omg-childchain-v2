defmodule Engine.Ethereum.HeightObserver.HeightManagmentTest do
  use ExUnit.Case, async: true
  alias Engine.Ethereum.HeightObserver.HeightManagement

  test "update_height/2 leaves internal state intact on error" do
    assert HeightManagement.update_height(%{}, :error) == %{}
  end

  test "update_height/2 updates internal state on height" do
    state = %{ethereum_height: 4, synced_at: DateTime.utc_now()}
    %{ethereum_height: 5, synced_at: _synced_at} = HeightManagement.update_height(state, 5)
  end

  test "recognizes stalled sync" do
    height = 5
    previous_height = 5
    synced_at = DateTime.utc_now()
    stall_threshold_ms = 95
    Process.sleep(100)
    assert HeightManagement.stalled?(height, previous_height, synced_at, stall_threshold_ms)
  end

  test "recognizes there's no stalled sync" do
    height = 5
    previous_height = 4
    synced_at = DateTime.utc_now()
    stall_threshold_ms = 95
    Process.sleep(100)
    refute HeightManagement.stalled?(height, previous_height, synced_at, stall_threshold_ms)
  end

  test "height gets published on the bus" do
    :ok = Bus.subscribe({:root_chain, "ethereum_new_height"}, link: true)
    HeightManagement.fetch_height_and_publish(%{eth_module: __MODULE__.EthMock, opts: []})
    assert_receive {:internal_event_bus, :ethereum_new_height, 17}
  end

  test "result on error does not get published on the bus" do
    :ok = Bus.subscribe({:root_chain, "ethereum_new_height"}, link: true)
    HeightManagement.fetch_height_and_publish(%{eth_module: __MODULE__.EthMockErr, opts: []})
    refute_receive {:internal_event_bus, :ethereum_new_height, _}
  end

  defmodule EthMock do
    def eth_block_number(_) do
      {:ok, "0x11"}
    end
  end

  defmodule EthMockErr do
    def eth_block_number(_) do
      {:error, :connection_refused}
    end
  end
end
