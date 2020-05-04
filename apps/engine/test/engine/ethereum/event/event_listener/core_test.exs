defmodule Engine.Ethereum.Event.Listener.CoreTest do
  use ExUnit.Case, async: true

  alias Engine.Ethereum.Event.Listener.Core
  alias Engine.Ethereum.Event.RootChainCoordinator.SyncGuide

  @service_name :name
  @request_max_size 5

  test "asks until root chain height provided" do
    state = create_state(0, request_max_size: 100)

    state
    |> Core.get_events_range_for_download(%SyncGuide{sync_height: 1, root_chain_height: 10})
    |> assert_range({1, 10})
  end

  test "max request size respected" do
    state = create_state(0, request_max_size: 2)

    state
    |> Core.get_events_range_for_download(%SyncGuide{sync_height: 1, root_chain_height: 10})
    |> assert_range({1, 2})
  end

  test "max request size ignored if caller is insiting to get a lot of events" do
    # this might be counterintuitive, but to we require that the requested sync_height is never left unhandled
    state = create_state(0, request_max_size: 2)

    state
    |> Core.get_events_range_for_download(%SyncGuide{sync_height: 4, root_chain_height: 10})
    |> assert_range({1, 4})
  end

  test "works well close to zero" do
    state = create_state(0)

    state
    |> Core.get_events_range_for_download(%SyncGuide{sync_height: 1, root_chain_height: 10})
    |> assert_range({1, 5})
    |> Core.add_new_events([event(1), event(3), event(4), event(5)])
    |> Core.get_events(0)
    |> assert_events(events: [], check_in_and_db: 0)
    |> Core.get_events(1)
    |> assert_events(events: [event(1)], check_in_and_db: 1)
    |> Core.get_events(2)
    |> assert_events(events: [], check_in_and_db: 2)
    |> Core.get_events(3)
    |> assert_events(events: [event(3)], check_in_and_db: 3)
  end

  test "always returns correct height to check in" do
    state = create_state(0)

    new_state =
      state
      |> Core.get_events_range_for_download(%SyncGuide{sync_height: 1, root_chain_height: 10})
      |> assert_range({1, 5})
      |> Core.get_events(0)
      |> assert_events(events: [], check_in_and_db: 0)

    assert new_state.synced_height == 0

    updated_state =
      new_state
      |> Core.get_events(1)
      |> assert_events(events: [], check_in_and_db: 1)

    assert updated_state.synced_height == 1
  end

  test "produces next ethereum height range to get events from" do
    state = create_state(0)

    state
    |> Core.get_events_range_for_download(%SyncGuide{sync_height: 5, root_chain_height: 10})
    |> assert_range({1, 5})
    |> Core.get_events_range_for_download(%SyncGuide{sync_height: 5, root_chain_height: 10})
    |> assert_range(:dont_fetch_events)
    |> Core.get_events_range_for_download(%SyncGuide{sync_height: 7, root_chain_height: 10})
    |> assert_range({6, 10})
    |> Core.get_events_range_for_download(%SyncGuide{sync_height: 7, root_chain_height: 10})
    |> assert_range(:dont_fetch_events)
  end

  test "if synced requested higher than root chain height" do
    # doesn't make too much sense, but still should work well
    state = create_state(0)

    state
    |> Core.get_events_range_for_download(%SyncGuide{sync_height: 5, root_chain_height: 5})
    |> assert_range({1, 5})
    |> Core.get_events_range_for_download(%SyncGuide{sync_height: 7, root_chain_height: 5})
    |> assert_range({6, 7})
  end

  test "will be eager to get more events, even if none are pulled at first. All will be returned" do
    state = create_state(0)

    state
    |> Core.get_events_range_for_download(%SyncGuide{sync_height: 2, root_chain_height: 2})
    |> assert_range({1, 2})
    |> Core.add_new_events([event(1), event(2)])
    |> Core.get_events_range_for_download(%SyncGuide{sync_height: 4, root_chain_height: 4})
    |> assert_range({3, 4})
    |> Core.add_new_events([event(3), event(4)])
    |> Core.get_events(4)
    |> assert_events(events: [event(1), event(2), event(3), event(4)], check_in_and_db: 4)
  end

  test "restart allows to continue with proper bounds" do
    state = create_state(1)

    state
    |> Core.get_events_range_for_download(%SyncGuide{sync_height: 4, root_chain_height: 10})
    |> assert_range({2, 6})
    |> Core.add_new_events([event(2), event(4), event(5), event(6)])
    |> Core.get_events_range_for_download(%SyncGuide{sync_height: 4, root_chain_height: 10})
    |> assert_range(:dont_fetch_events)
    |> Core.get_events(4)
    |> assert_events(events: [event(2), event(4)], check_in_and_db: 4)
    |> Core.get_events_range_for_download(%SyncGuide{sync_height: 5, root_chain_height: 10})
    |> assert_range(:dont_fetch_events)
    |> Core.get_events(5)
    |> assert_events(events: [event(5)], check_in_and_db: 5)

    state2 = create_state(3)

    state2
    |> Core.get_events_range_for_download(%SyncGuide{sync_height: 3, root_chain_height: 10})
    |> assert_range(:dont_fetch_events)
    |> Core.get_events_range_for_download(%SyncGuide{sync_height: 5, root_chain_height: 10})
    |> assert_range({4, 8})
    |> Core.add_new_events([event(4), event(5), event(7)])
    |> Core.get_events(3)
    |> assert_events(events: [], check_in_and_db: 3)
    |> Core.get_events(5)
    |> assert_events(events: [event(4), event(5)], check_in_and_db: 5)

    state3 = create_state(3)

    state3
    |> Core.get_events_range_for_download(%SyncGuide{sync_height: 7, root_chain_height: 10})
    |> assert_range({4, 8})
    |> Core.add_new_events([event(4), event(5), event(7)])
    |> Core.get_events(7)
    |> assert_events(events: [event(4), event(5), event(7)], check_in_and_db: 7)
  end

  test "can get multiple events from one height" do
    state = create_state(5)

    state
    |> Core.get_events_range_for_download(%SyncGuide{sync_height: 6, root_chain_height: 10})
    |> assert_range({6, 10})
    |> Core.add_new_events([event(6), event(6), event(7)])
    |> Core.get_events(6)
    |> assert_events(events: [event(6), event(6)], check_in_and_db: 6)
  end

  test "can get an empty events list when events too fresh" do
    state = create_state(4)

    state
    |> Core.get_events_range_for_download(%SyncGuide{sync_height: 6, root_chain_height: 10})
    |> assert_range({5, 9})
    |> Core.add_new_events([event(5), event(5), event(6)])
    |> Core.get_events(4)
    |> assert_events(events: [], check_in_and_db: 4)
  end

  test "doesn't fail when getting events from empty" do
    state = create_state(1)

    state
    |> Core.get_events(5)
    |> assert_events(events: [], check_in_and_db: 5)
  end

  test "persists/checks in eth_height without margins substracted, and never goes negative" do
    state = create_state(0, request_max_size: 10)

    new_state =
      state
      |> Core.get_events_range_for_download(%SyncGuide{sync_height: 6, root_chain_height: 10})
      |> assert_range({1, 10})
      |> Core.add_new_events([event(6), event(7), event(8), event(9)])

    for i <- 1..9, do: new_state |> Core.get_events(i) |> assert_events(check_in_and_db: i)
  end

  test "tolerates being asked to sync on height already synced" do
    state = create_state(5)

    state
    |> Core.get_events_range_for_download(%SyncGuide{sync_height: 1, root_chain_height: 10})
    |> assert_range(:dont_fetch_events)
    |> Core.add_new_events([])
    |> Core.get_events(1)
    |> assert_events(events: [], check_in_and_db: 5)
  end

  defp create_state(height, opts \\ []) do
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    ets = :ets.new(String.to_atom("test-#{:rand.uniform(2000)}"), [:set, :public, :named_table])
    request_max_size = Keyword.get(opts, :request_max_size, @request_max_size)
    # this assert is meaningful - currently we want to explicitly check_in the height read from DB
    state = Core.init(@service_name, height, request_max_size, ets)
    assert ^height = state.synced_height
    state
  end

  defp event(height), do: %{eth_height: height}

  defp assert_range({:get_events, range, state}, expect) do
    assert range == expect
    state
  end

  defp assert_range({:dont_fetch_events, state}, expect) do
    assert :dont_fetch_events == expect
    state
  end

  defp assert_events(response, opts) do
    expected_check_in_and_db = Keyword.get(opts, :check_in_and_db)
    expected_events = Keyword.get(opts, :events)
    assert {:ok, events, check_in_and_db, new_state} = response
    if expected_events, do: assert(expected_events == events)
    if expected_check_in_and_db, do: assert(expected_check_in_and_db == check_in_and_db)
    new_state
  end
end
