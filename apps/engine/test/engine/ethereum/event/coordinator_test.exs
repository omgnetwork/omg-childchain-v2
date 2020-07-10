defmodule Engine.Ethereum.Event.CoordinatorTest do
  use ExUnit.Case, async: true
  alias Engine.Ethereum.Event.Coordinator.Core
  alias Engine.Ethereum.Event.Coordinator.Setup

  setup do
    {_args, config_services} = Setup.coordinator_setup(1, 1, 1)
    init = Core.init(config_services, 10)

    pid =
      config_services
      |> Map.keys()
      |> Enum.with_index(1)
      |> Enum.into(%{}, fn {key, idx} -> {key, :c.pid(0, idx, 0)} end)

    {:ok, %{state: initial_check_in(init, Map.keys(config_services), pid), pid: pid}}
  end

  test "syncs services correctly", %{state: state, pid: pid} do
    # NOTE: this assumes some finality margines embedded in `config/test.exs`. Consider refactoring if these
    #       needs to change and break this test, instead of modifying this test!

    # start - only depositor and getter allowed to move
    assert %{sync_height: 9, root_chain_height: 9} = Core.get_synced_info(state, pid[:depositor])
    assert %{sync_height: 0, root_chain_height: 9} = Core.get_synced_info(state, pid[:exiter])
    assert %{sync_height: 0, root_chain_height: 9} = Core.get_synced_info(state, pid[:in_flight_exit])

    # depositor advances
    assert {:ok, state} = Core.check_in(state, pid[:depositor], 10, :depositor)
    assert %{sync_height: 9, root_chain_height: 9} = Core.get_synced_info(state, pid[:exiter])
    assert %{sync_height: 9, root_chain_height: 9} = Core.get_synced_info(state, pid[:in_flight_exit])

    # in_flight_exit advances
    assert %{sync_height: 0, root_chain_height: 9} = Core.get_synced_info(state, pid[:piggyback])
    assert {:ok, state} = Core.check_in(state, pid[:in_flight_exit], 10, :in_flight_exit)
    assert %{sync_height: 9, root_chain_height: 9} = Core.get_synced_info(state, pid[:piggyback])

    # root chain advances
    assert {:ok, state} = Core.update_root_chain_height(state, 100)
    assert %{sync_height: 99, root_chain_height: 99} = Core.get_synced_info(state, pid[:depositor])
    assert %{sync_height: 10, root_chain_height: 99} = Core.get_synced_info(state, pid[:exiter])
    assert %{sync_height: 10, root_chain_height: 99} = Core.get_synced_info(state, pid[:in_flight_exit])
    assert %{sync_height: 10, root_chain_height: 99} = Core.get_synced_info(state, pid[:piggyback])
  end

  defp initial_check_in(state, services, pid) do
    {:ok, state} =
      Enum.reduce(services, {:ok, state}, fn service, {:ok, state} ->
        Core.check_in(state, pid[service], 0, service)
      end)

    state
  end
end
