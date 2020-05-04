defmodule Engine.Ethereum.Event.RootChainCoordinator.CoreTest do
  use ExUnit.Case, async: true

  alias Engine.Ethereum.Event.RootChainCoordinator.Core

  @pid %{
    depositor: :c.pid(0, 1, 0),
    exiter: :c.pid(0, 2, 0),
    depositor_finality: :c.pid(0, 3, 0),
    exiter_finality: :c.pid(0, 4, 0),
    getter: :c.pid(0, 5, 0),
    finalizer: :c.pid(0, 6, 0)
  }

  test "does not synchronize service that is not allowed" do
    state = state()
    {:error, :service_not_allowed} = Core.check_in(state, :c.pid(0, 1, 0), 10, :unallowed_service)
  end

  test "synchronizes services" do
    state = state()
    depositor_pid = :c.pid(0, 1, 0)
    exiter_pid = :c.pid(0, 2, 0)

    assert {:ok, state} = Core.check_in(state, exiter_pid, 1, :exiter)
    assert :nosync = Core.get_synced_info(state, depositor_pid)
    assert :nosync = Core.get_synced_info(state, exiter_pid)

    assert {:ok, state} = Core.check_in(state, depositor_pid, 2, :depositor)
    assert %{sync_height: 10} = Core.get_synced_info(state, depositor_pid)
    assert %{sync_height: 2} = Core.get_synced_info(state, exiter_pid)

    assert {:ok, state} = Core.check_in(state, exiter_pid, 2, :exiter)
    assert %{sync_height: 10} = Core.get_synced_info(state, depositor_pid)
    assert %{sync_height: 2} = Core.get_synced_info(state, exiter_pid)

    assert {:ok, state} = Core.check_in(state, depositor_pid, 3, :depositor)
    assert %{sync_height: 10} = Core.get_synced_info(state, depositor_pid)
    assert %{sync_height: 3} = Core.get_synced_info(state, exiter_pid)
  end

  test "deregisters and registers a service" do
    state = state()
    depositor_pid = :c.pid(0, 1, 0)
    exiter_pid = :c.pid(0, 2, 0)

    assert {:ok, state} = Core.check_in(state, exiter_pid, 1, :exiter)
    assert {:ok, state} = Core.check_in(state, depositor_pid, 1, :depositor)
    assert %{sync_height: 10} = Core.get_synced_info(state, depositor_pid)
    assert %{sync_height: 1} = Core.get_synced_info(state, exiter_pid)

    depositor_pid2 = :c.pid(0, 3, 0)
    assert {:ok, state} = Core.check_in(state, depositor_pid2, 2, :depositor)
    assert %{sync_height: 10} = Core.get_synced_info(state, depositor_pid2)
    assert %{sync_height: 2} = Core.get_synced_info(state, exiter_pid)
  end

  test "updates root chain height" do
    state = state()
    depositor_pid = :c.pid(0, 1, 0)
    exiter_pid = :c.pid(0, 2, 0)

    assert {:ok, state} = Core.check_in(state, exiter_pid, 10, :exiter)
    assert {:ok, state} = Core.check_in(state, depositor_pid, 10, :depositor)
    assert %{sync_height: 10} = Core.get_synced_info(state, depositor_pid)
    assert %{sync_height: 10} = Core.get_synced_info(state, exiter_pid)

    assert {:ok, state} = Core.update_root_chain_height(state, 11)
    assert %{sync_height: 11} = Core.get_synced_info(state, depositor_pid)
    assert %{sync_height: 10} = Core.get_synced_info(state, exiter_pid)

    assert {:ok, state} = Core.update_root_chain_height(state, 14)
    assert %{sync_height: 14} = Core.get_synced_info(state, depositor_pid)
    assert %{sync_height: 10} = Core.get_synced_info(state, exiter_pid)
  end

  test "reports synced heights" do
    state = state()
    exiter_pid = :c.pid(0, 2, 0)

    assert %{root_chain_height: 10} == Core.get_ethereum_heights(state)
    assert {:ok, state} = Core.check_in(state, exiter_pid, 10, :exiter)
    assert %{root_chain_height: 10, exiter: 10} == Core.get_ethereum_heights(state)
    assert {:ok, state} = Core.update_root_chain_height(state, 11)
    assert %{root_chain_height: 11, exiter: 10} == Core.get_ethereum_heights(state)
  end

  test "prevents huge queries to Ethereum client" do
    state = state()
    depositor_pid = :c.pid(0, 1, 0)
    exiter_pid = :c.pid(0, 2, 0)

    assert {:ok, state} = Core.check_in(state, exiter_pid, 10, :exiter)
    assert {:ok, state} = Core.check_in(state, depositor_pid, 10, :depositor)
    assert {:ok, state} = Core.update_root_chain_height(state, 11_000_000)
    assert %{sync_height: new_sync_height} = Core.get_synced_info(state, depositor_pid)
    assert new_sync_height < 100_000
  end

  test "root chain back off is ignored" do
    state = state()
    depositor_pid = :c.pid(0, 1, 0)
    exiter_pid = :c.pid(0, 2, 0)

    assert {:ok, state} = Core.check_in(state, exiter_pid, 10, :exiter)
    assert {:ok, state} = Core.check_in(state, depositor_pid, 10, :depositor)
    assert %{sync_height: 10} = Core.get_synced_info(state, depositor_pid)
    assert %{sync_height: 10} = Core.get_synced_info(state, exiter_pid)

    assert {:ok, state} = Core.update_root_chain_height(state, 9)
    assert %{sync_height: 10} = Core.get_synced_info(state, depositor_pid)
    assert %{sync_height: 10} = Core.get_synced_info(state, exiter_pid)

    assert {:ok, state} = Core.update_root_chain_height(state, 11)
    assert %{sync_height: 11} = Core.get_synced_info(state, depositor_pid)
    assert %{sync_height: 10} = Core.get_synced_info(state, exiter_pid)
  end

  test "waiting service will wait and progress accordingly" do
    assert %{sync_height: 1} = Core.get_synced_info(bigger_state(), @pid[:exiter])
    {:ok, state1} = Core.check_in(bigger_state(), @pid[:depositor], 2, :depositor)
    assert %{sync_height: 2} = Core.get_synced_info(state1, @pid[:exiter])
    {:ok, state2} = Core.check_in(state1, @pid[:depositor], 5, :depositor)
    assert %{sync_height: 5} = Core.get_synced_info(state2, @pid[:exiter])
  end

  test "waiting for multiple" do
    assert %{sync_height: 1} = Core.get_synced_info(bigger_state(), @pid[:finalizer])
    {:ok, state1} = Core.check_in(bigger_state(), @pid[:depositor], 2, :depositor)
    assert %{sync_height: 1} = Core.get_synced_info(state1, @pid[:finalizer])
    {:ok, state2} = Core.check_in(state1, @pid[:getter], 2, :getter)
    assert %{sync_height: 2} = Core.get_synced_info(state2, @pid[:finalizer])
    {:ok, state3} = Core.check_in(state2, @pid[:depositor], 5, :depositor)
    {:ok, state4} = Core.check_in(state3, @pid[:getter], 5, :getter)
    assert %{sync_height: 5} = Core.get_synced_info(state4, @pid[:finalizer])
  end

  test "waiting when margin of the awaited process should be skipped ahead" do
    assert %{sync_height: 3} = Core.get_synced_info(bigger_state(), @pid[:getter])
    {:ok, state} = Core.check_in(bigger_state(), @pid[:depositor_finality], 5, :depositor_finality)
    assert %{sync_height: 7} = Core.get_synced_info(state, @pid[:getter])
    {:ok, state1} = Core.check_in(state, @pid[:depositor_finality], 8, :depositor_finality)
    assert %{sync_height: 10} = Core.get_synced_info(state1, @pid[:getter])

    assert {:ok, state2} = Core.update_root_chain_height(state1, 11)

    assert %{sync_height: 10} = Core.get_synced_info(state2, @pid[:getter])
    {:ok, state3} = Core.check_in(state2, @pid[:depositor_finality], 9, :depositor_finality)
    assert %{sync_height: 11} = Core.get_synced_info(state3, @pid[:getter])

    # sanity check - will not accidently spill over root chain height (but depositor wouldn't likely check in at 11)
    {:ok, state4} = Core.check_in(state3, @pid[:depositor_finality], 11, :depositor_finality)
    assert %{sync_height: 11} = Core.get_synced_info(state4, @pid[:getter])
  end

  test "waiting only for the finality margin" do
    assert %{sync_height: 8} = Core.get_synced_info(bigger_state(), @pid[:depositor_finality])
    {:ok, state} = Core.check_in(bigger_state(), @pid[:depositor_finality], 5, :depositor_finality)
    assert %{sync_height: 8} = Core.get_synced_info(state, @pid[:depositor_finality])
    assert {:ok, state1} = Core.update_root_chain_height(state, 11)
    assert %{sync_height: 9} = Core.get_synced_info(state1, @pid[:depositor_finality])
  end

  test "waiting only for the finality margin and some service" do
    assert %{sync_height: 1} = Core.get_synced_info(bigger_state(), @pid[:exiter_finality])
    {:ok, state} = Core.check_in(bigger_state(), @pid[:depositor], 5, :depositor)
    assert %{sync_height: 5} = Core.get_synced_info(state, @pid[:exiter_finality])
    assert {:ok, state1} = Core.update_root_chain_height(state, 11)
    assert %{sync_height: 5} = Core.get_synced_info(state1, @pid[:exiter_finality])
    {:ok, state2} = Core.check_in(state1, @pid[:depositor], 9, :depositor)
    assert %{sync_height: 9} = Core.get_synced_info(state2, @pid[:exiter_finality])

    # is reorg safe - root chain height going backwards is ignored
    assert {:ok, state3} = Core.update_root_chain_height(state2, 10)
    assert %{sync_height: 9} = Core.get_synced_info(state3, @pid[:exiter_finality])
  end

  test "behaves well close to zero" do
    state = Core.init(%{:depositor => [finality_margin: 2], :exiter => [waits_for: :depositor, finality_margin: 2]}, 0)

    state1 =
      Enum.reduce([:depositor, :exiter], state, fn item, state ->
        {:ok, new_state} = Core.check_in(state, @pid[item], 0, item)
        new_state
      end)

    assert %{sync_height: 0} = Core.get_synced_info(state1, @pid[:depositor])
    assert %{sync_height: 0} = Core.get_synced_info(state1, @pid[:exiter])
    assert {:ok, state2} = Core.update_root_chain_height(state1, 1)
    assert %{sync_height: 0} = Core.get_synced_info(state2, @pid[:depositor])
    assert %{sync_height: 0} = Core.get_synced_info(state2, @pid[:exiter])
    assert {:ok, state3} = Core.update_root_chain_height(state2, 3)
    assert %{sync_height: 1} = Core.get_synced_info(state3, @pid[:depositor])
    assert %{sync_height: 0} = Core.get_synced_info(state3, @pid[:exiter])
    {:ok, state4} = Core.check_in(state3, @pid[:depositor], 1, :depositor)
    assert %{sync_height: 1} = Core.get_synced_info(state4, @pid[:exiter])
  end

  test "root chain heights reported observe the finality margin, if present" do
    state = bigger_state()
    assert %{root_chain_height: 10} = Core.get_synced_info(state, @pid[:depositor])
    assert %{root_chain_height: 8} = Core.get_synced_info(state, @pid[:depositor_finality])
    assert %{root_chain_height: 10} = Core.get_synced_info(state, @pid[:exiter])
    assert %{root_chain_height: 8} = Core.get_synced_info(state, @pid[:exiter_finality])
    assert %{root_chain_height: 10} = Core.get_synced_info(state, @pid[:getter])
  end

  defp state() do
    Core.init(%{:depositor => [], :exiter => [waits_for: :depositor]}, 10)
  end

  defp bigger_state() do
    state =
      Core.init(
        %{
          :depositor => [],
          :exiter => [waits_for: :depositor],
          :depositor_finality => [finality_margin: 2],
          :exiter_finality => [waits_for: :depositor, finality_margin: 2],
          :getter => [waits_for: [depositor_finality: :no_margin]],
          :finalizer => [waits_for: [:getter, :depositor]]
        },
        10
      )

    services = [:depositor, :exiter, :depositor_finality, :exiter_finality, :getter, :finalizer]

    check_in(services, state)
  end

  defp check_in(services, state) do
    Enum.reduce(services, state, fn item, state ->
      {:ok, new_state} = Core.check_in(state, @pid[item], 1, item)
      new_state
    end)
  end
end
