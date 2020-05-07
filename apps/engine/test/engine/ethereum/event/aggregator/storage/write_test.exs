defmodule Engine.Ethereum.Event.Aggregator.Storage.WriteTest do
  @moduledoc """
  need to do it (it's tested in aggregator_test.exs but was split now in chilchain)
  """
  use ExUnit.Case, async: true
  alias Engine.Ethereum.Event.Aggregator
  alias Engine.Ethereum.Event.Aggregator.Storage
  alias Engine.Ethereum.Event.Aggregator.Storage.Write
  alias Engine.Ethereum.RootChain.Event

  setup %{test: name} do
    ets = Storage.events_bucket(name)

    %{state: %Aggregator{ets: ets}}
  end

  describe "logs/4" do
    test "empty data gets persisted for every height we visited", %{state: state} do
      Write.logs([], 1, 2, struct(state, event_signatures: ["DepositCreated(Eeny,meeny,miny,moe)"]))

      assert :ets.tab2list(state.ets) == [
               {1, "DepositCreated(Eeny,meeny,miny,moe)", []},
               {2, "DepositCreated(Eeny,meeny,miny,moe)", []}
             ]
    end

    test "simple data gets persisted for every height we visited", %{state: state} do
      event_signature = "DepositCreated(Eeny,meeny,miny,moe)"
      event1 = %Event{eth_height: 1, event_signature: event_signature}
      event2 = %Event{eth_height: 2, event_signature: event_signature}
      Write.logs([event1, event2], 1, 2, struct(state, event_signatures: [event_signature]))

      assert :ets.tab2list(state.ets) == [
               {1, event_signature, [event1]},
               {2, event_signature, [event2]}
             ]
    end

    test "data gets persisted for every height we visited", %{state: state} do
      event_signature1 = "DepositCreated(Eeny,meeny,miny,moe)"
      event_signature2 = "SomethingCreated(integer,address,yolo)"
      event1 = %Event{eth_height: 1, event_signature: event_signature1}
      event2 = %Event{eth_height: 2, event_signature: event_signature2}
      Write.logs([event1, event2], 1, 2, struct(state, event_signatures: [event_signature1, event_signature2]))

      assert :ets.tab2list(state.ets) == [
               {1, event_signature1, [event1]},
               {1, event_signature2, []},
               {2, event_signature2, [event2]},
               {2, event_signature1, []}
             ]
    end

    test "data gets persisted for every height we visited (when there are more events on the same height)", %{
      state: state
    } do
      event_signature1 = "DepositCreated(Eeny,meeny,miny,moe)"
      event_signature2 = "SomethingCreated(integer,address,yolo)"
      event1 = %Event{eth_height: 1, event_signature: event_signature1}
      event11 = %Event{eth_height: 1, event_signature: event_signature1, root_chain_tx_hash: <<"event11">>}
      event2 = %Event{eth_height: 2, event_signature: event_signature2}
      Write.logs([event1, event11, event2], 1, 2, struct(state, event_signatures: [event_signature1, event_signature2]))

      assert :ets.tab2list(state.ets) == [
               {1, event_signature1, [event1, event11]},
               {1, event_signature2, []},
               {2, event_signature2, [event2]},
               {2, event_signature1, []}
             ]
    end
  end
end
