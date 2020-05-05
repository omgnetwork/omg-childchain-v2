defmodule Engine.Ethereum.Event.Aggregator.StorageTest do
  @moduledoc """
  need to do it (it's tested in aggregator_test.exs but was split now in chilchain)
  """
  use ExUnit.Case, async: true

  alias Engine.Ethereum.Event.Aggregator
  alias Engine.Ethereum.Event.Aggregator.Storage
  alias Engine.Ethereum.Event.Aggregator.Storage.Write
  alias Engine.Ethereum.RootChain.Event

  describe "events_bucket/0/1" do
    test "the ets table created is a bag", %{test: name} do
      Storage.events_bucket(name)
      info = :ets.info(name)
      assert Keyword.fetch!(info, :named_table) == true
      assert Keyword.fetch!(info, :type) == :bag
    end
  end

  describe "delete_old_logs/2" do
    test "cleanup works for simple data", %{test: name} do
      ets = Storage.events_bucket(name)
      event_signature = "DepositCreated(Eeny,meeny,miny,moe)"
      event1 = %Event{eth_height: 1, event_signature: event_signature}
      event2 = %Event{eth_height: 2, event_signature: event_signature}
      state = struct(Aggregator, ets: ets, event_signatures: [event_signature], number_of_events_kept_in_ets: 1)
      :ok = Write.logs([event1, event2], 1, 2, state)
      Storage.delete_old_logs(2, state)
      assert Enum.count(:ets.tab2list(ets)) == 1
      assert ets |> :ets.tab2list() |> hd() |> elem(0) == 2
    end

    test "cleanup works for simple data (wipe clean because number_of_events_kept_in_ets is 0 )", %{
      test: name
    } do
      ets = Storage.events_bucket(name)
      event_signature = "DepositCreated(Eeny,meeny,miny,moe)"
      tip_eth_height = 2
      event1 = %Event{eth_height: 1, event_signature: event_signature}
      event2 = %Event{eth_height: tip_eth_height, event_signature: event_signature}

      state =
        struct(Aggregator,
          ets: ets,
          event_signatures: [event_signature],
          number_of_events_kept_in_ets: 0
        )

      :ok = Write.logs([event1, event2], 1, 2, state)
      Storage.delete_old_logs(2, state)
      assert Enum.empty?(:ets.tab2list(ets)) == true
    end
  end
end
