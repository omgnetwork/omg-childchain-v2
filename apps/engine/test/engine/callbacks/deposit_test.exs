defmodule Engine.Callbacks.DepositTest do
  @moduledoc false

  use Engine.DB.DataCase, async: true

  alias Engine.Callbacks.Deposit
  alias Engine.DB.Block
  alias Engine.DB.ListenerState
  alias Engine.DB.Output
  alias Engine.DB.Transaction

  test "generates a confirmed transaction, block and utxo for the deposit" do
    deposit_event = %{
      data: %{
        "amount" => 1_000_000_000_000_000_000,
        "blknum" => 3,
        "token" => <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
        "depositor" => <<55, 1, 205, 186, 148, 200, 85, 8, 213, 44, 97, 189, 196, 39, 129, 163, 245, 230, 23, 206>>
      },
      eth_height: 404,
      event_signature: "DepositCreated(address,uint256,address,uint256)",
      log_index: 1,
      root_chain_tx_hash:
        <<84, 133, 148, 16, 138, 47, 89, 9, 12, 99, 34, 212, 19, 11, 55, 155, 143, 238, 249, 66, 56, 169, 15, 72, 105,
          33, 184, 110, 48, 23, 144, 38>>
    }

    assert {:ok, %{"deposit-blknum-3" => block}} = Deposit.callback([deposit_event], :depositor)
    assert %Block{number: 3, state: "confirmed"} = block

    block = Repo.preload(block, :transactions)

    assert %Transaction{outputs: [output]} = hd(block.transactions)
    assert %Output{output_data: data} = output
    assert %ExPlasma.Output{output_data: %{amount: 1_000_000_000_000_000_000}} = ExPlasma.Output.decode(data)
  end

  test "takes multiple deposit events" do
    deposit_events = [
      %{
        data: %{
          "amount" => 1_000_000_000_000_000_000,
          "blknum" => 6,
          "token" => <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
          "depositor" => <<55, 1, 205, 186, 148, 200, 85, 8, 213, 44, 97, 189, 196, 39, 129, 163, 245, 230, 23, 206>>
        },
        eth_height: 404,
        event_signature: "DepositCreated(address,uint256,address,uint256)",
        log_index: 1,
        root_chain_tx_hash:
          <<84, 133, 148, 16, 138, 47, 89, 9, 12, 99, 34, 212, 19, 11, 55, 155, 143, 238, 249, 66, 56, 169, 15, 72, 105,
            33, 184, 110, 48, 23, 144, 38>>
      },
      %{
        data: %{
          "amount" => 1_000_000_000_000_000_000,
          "blknum" => 5,
          "token" => <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
          "depositor" => <<55, 1, 205, 186, 148, 200, 85, 8, 213, 44, 97, 189, 196, 39, 129, 163, 245, 230, 23, 206>>
        },
        eth_height: 403,
        event_signature: "DepositCreated(address,uint256,address,uint256)",
        log_index: 1,
        root_chain_tx_hash:
          <<84, 133, 148, 16, 138, 47, 89, 9, 12, 99, 34, 212, 19, 11, 55, 155, 143, 238, 249, 66, 56, 169, 15, 72, 105,
            33, 184, 110, 48, 23, 144, 38>>
      }
    ]

    assert {:ok, %{"deposit-blknum-6" => block6, "deposit-blknum-5" => block5}} =
             Deposit.callback(deposit_events, :depositor)

    assert %Block{number: 6, state: "confirmed"} = block6
    assert %Block{number: 5, state: "confirmed"} = block5
  end

  test "does not re-insert existing deposit events" do
    deposit_events = [
      %{
        data: %{
          "amount" => 1_000_000_000_000_000_000,
          "blknum" => 11,
          "token" => <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
          "depositor" => <<55, 1, 205, 186, 148, 200, 85, 8, 213, 44, 97, 189, 196, 39, 129, 163, 245, 230, 23, 206>>
        },
        eth_height: 404,
        event_signature: "DepositCreated(address,uint256,address,uint256)",
        log_index: 1,
        root_chain_tx_hash:
          <<84, 133, 148, 16, 138, 47, 89, 9, 12, 99, 34, 212, 19, 11, 55, 155, 143, 238, 249, 66, 56, 169, 15, 72, 105,
            33, 184, 110, 48, 23, 144, 38>>
      },
      %{
        data: %{
          "amount" => 1_000_000_000_000_000_000,
          "blknum" => 12,
          "token" => <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
          "depositor" => <<55, 1, 205, 186, 148, 200, 85, 8, 213, 44, 97, 189, 196, 39, 129, 163, 245, 230, 23, 206>>
        },
        eth_height: 403,
        event_signature: "DepositCreated(address,uint256,address,uint256)",
        log_index: 1,
        root_chain_tx_hash:
          <<84, 133, 148, 16, 138, 47, 89, 9, 12, 99, 34, 212, 19, 11, 55, 155, 143, 238, 249, 66, 56, 169, 15, 72, 105,
            33, 184, 110, 48, 23, 144, 38>>
      }
    ]

    new_deposit_events = [
      %{
        data: %{
          "amount" => 1_000_000_000_000_000_000,
          "blknum" => 13,
          "token" => <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
          "depositor" => <<55, 1, 205, 186, 148, 200, 85, 8, 213, 44, 97, 189, 196, 39, 129, 163, 245, 230, 23, 206>>
        },
        eth_height: 405,
        event_signature: "DepositCreated(address,uint256,address,uint256)",
        log_index: 1,
        root_chain_tx_hash:
          <<84, 133, 148, 16, 138, 47, 89, 9, 12, 99, 34, 212, 19, 11, 55, 155, 143, 238, 249, 66, 56, 169, 15, 72, 105,
            33, 184, 110, 48, 23, 144, 38>>
      }
    ]

    assert {:ok, %{"deposit-blknum-11" => _, "deposit-blknum-12" => _}} = Deposit.callback(deposit_events, :depositor)
    assert {:ok, %{"deposit-blknum-13" => _}} = Deposit.callback(deposit_events ++ new_deposit_events, :depositor)
    assert 3 == Repo.one(from(b in Engine.DB.Block, select: count(b.id)))

    assert %ListenerState{height: 405, listener: "depositor"} = Engine.Repo.get(ListenerState, "#{:depositor}")
  end

  test "three listeners try to commit deposits from different starting heights" do
    deposit_events_listener1 = [
      %{
        data: %{
          "amount" => 1_000_000_000_000_000_000,
          "blknum" => 3,
          "token" => <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
          "depositor" => <<55, 1, 205, 186, 148, 200, 85, 8, 213, 44, 97, 189, 196, 39, 129, 163, 245, 230, 23, 206>>
        },
        eth_height: 404,
        event_signature: "DepositCreated(address,uint256,address,uint256)",
        log_index: 1,
        root_chain_tx_hash:
          <<84, 133, 148, 16, 138, 47, 89, 9, 12, 99, 34, 212, 19, 11, 55, 155, 143, 238, 249, 66, 56, 169, 15, 72, 105,
            33, 184, 110, 48, 23, 144, 38>>
      },
      %{
        data: %{
          "amount" => 1_000_000_000_000_000_000,
          "blknum" => 4,
          "token" => <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
          "depositor" => <<55, 1, 205, 186, 148, 200, 85, 8, 213, 44, 97, 189, 196, 39, 129, 163, 245, 230, 23, 206>>
        },
        eth_height: 405,
        event_signature: "DepositCreated(address,uint256,address,uint256)",
        log_index: 1,
        root_chain_tx_hash:
          <<84, 133, 148, 16, 138, 47, 89, 9, 12, 99, 34, 212, 19, 11, 55, 155, 143, 238, 249, 66, 56, 169, 15, 72, 105,
            33, 184, 110, 48, 23, 144, 38>>
      }
    ]

    deposit_events_listener2 = [
      %{
        data: %{
          "amount" => 1_000_000_000_000_000_000,
          "blknum" => 3,
          "token" => <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
          "depositor" => <<55, 1, 205, 186, 148, 200, 85, 8, 213, 44, 97, 189, 196, 39, 129, 163, 245, 230, 23, 206>>
        },
        eth_height: 404,
        event_signature: "DepositCreated(address,uint256,address,uint256)",
        log_index: 1,
        root_chain_tx_hash:
          <<84, 133, 148, 16, 138, 47, 89, 9, 12, 99, 34, 212, 19, 11, 55, 155, 143, 238, 249, 66, 56, 169, 15, 72, 105,
            33, 184, 110, 48, 23, 144, 38>>
      },
      %{
        data: %{
          "amount" => 1_000_000_000_000_000_000,
          "blknum" => 4,
          "token" => <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
          "depositor" => <<55, 1, 205, 186, 148, 200, 85, 8, 213, 44, 97, 189, 196, 39, 129, 163, 245, 230, 23, 206>>
        },
        eth_height: 405,
        event_signature: "DepositCreated(address,uint256,address,uint256)",
        log_index: 1,
        root_chain_tx_hash:
          <<84, 133, 148, 16, 138, 47, 89, 9, 12, 99, 34, 212, 19, 11, 55, 155, 143, 238, 249, 66, 56, 169, 15, 72, 105,
            33, 184, 110, 48, 23, 144, 38>>
      },
      %{
        data: %{
          "amount" => 1_000_000_000_000_000_000,
          "blknum" => 5,
          "token" => <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
          "depositor" => <<55, 1, 205, 186, 148, 200, 85, 8, 213, 44, 97, 189, 196, 39, 129, 163, 245, 230, 23, 206>>
        },
        eth_height: 406,
        event_signature: "DepositCreated(address,uint256,address,uint256)",
        log_index: 1,
        root_chain_tx_hash:
          <<84, 133, 148, 16, 138, 47, 89, 9, 12, 99, 34, 212, 19, 11, 55, 155, 143, 238, 249, 66, 56, 169, 15, 72, 105,
            33, 184, 110, 48, 23, 144, 38>>
      }
    ]

    deposit_events_listener3 = [
      %{
        data: %{
          "amount" => 1_000_000_000_000_000_000,
          "blknum" => 4,
          "token" => <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
          "depositor" => <<55, 1, 205, 186, 148, 200, 85, 8, 213, 44, 97, 189, 196, 39, 129, 163, 245, 230, 23, 206>>
        },
        eth_height: 405,
        event_signature: "DepositCreated(address,uint256,address,uint256)",
        log_index: 1,
        root_chain_tx_hash:
          <<84, 133, 148, 16, 138, 47, 89, 9, 12, 99, 34, 212, 19, 11, 55, 155, 143, 238, 249, 66, 56, 169, 15, 72, 105,
            33, 184, 110, 48, 23, 144, 38>>
      },
      %{
        data: %{
          "amount" => 1_000_000_000_000_000_000,
          "blknum" => 5,
          "token" => <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
          "depositor" => <<55, 1, 205, 186, 148, 200, 85, 8, 213, 44, 97, 189, 196, 39, 129, 163, 245, 230, 23, 206>>
        },
        eth_height: 406,
        event_signature: "DepositCreated(address,uint256,address,uint256)",
        log_index: 1,
        root_chain_tx_hash:
          <<84, 133, 148, 16, 138, 47, 89, 9, 12, 99, 34, 212, 19, 11, 55, 155, 143, 238, 249, 66, 56, 169, 15, 72, 105,
            33, 184, 110, 48, 23, 144, 38>>
      }
    ]

    assert {:ok, %{"deposit-blknum-3" => _, "deposit-blknum-4" => _}} =
             Deposit.callback(deposit_events_listener1, :depositor)

    assert %ListenerState{height: 405, listener: "depositor"} = Engine.Repo.get(ListenerState, "#{:depositor}")

    assert 2 == Repo.one(from(b in Engine.DB.Block, select: count(b.id)))

    assert {:ok, %{"deposit-blknum-5" => _}} = Deposit.callback(deposit_events_listener2, :depositor)

    assert %ListenerState{height: 406, listener: "depositor"} = Engine.Repo.get(ListenerState, "#{:depositor}")

    assert 3 == Repo.one(from(b in Engine.DB.Block, select: count(b.id)))

    assert {:ok, _} = Deposit.callback(deposit_events_listener3, :depositor)

    assert %ListenerState{height: 406, listener: "depositor"} = Engine.Repo.get(ListenerState, "#{:depositor}")

    assert 3 == Repo.one(from(b in Engine.DB.Block, select: count(b.id)))

    assert {:ok, _} = Deposit.callback(deposit_events_listener3, :depositor)

    assert %ListenerState{height: 406, listener: "depositor"} = Engine.Repo.get(ListenerState, "#{:depositor}")
  end
end
