defmodule Engine.Callbacks.DepositTest do
  @moduledoc false

  use ExUnit.Case, async: true
  import Ecto.Query

  alias Ecto.Adapters.SQL.Sandbox
  alias Engine.Callbacks.Deposit
  alias Engine.DB.Block
  alias Engine.DB.Output
  alias Engine.DB.Transaction
  alias Engine.Repo

  setup do
    :ok = Sandbox.checkout(Repo)
  end

  @tag :focus
  describe "deposit/1" do
    test "generates a confirmed transaction, block and utxo for the deposit" do
      deposit_event = %{
        amount: 1_000_000_000_000_000_000,
        blknum: 3,
        currency: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
        eth_height: 404,
        event_signature: "DepositCreated(address,uint256,address,uint256)",
        log_index: 1,
        owner: <<55, 1, 205, 186, 148, 200, 85, 8, 213, 44, 97, 189, 196, 39, 129, 163, 245, 230, 23, 206>>,
        root_chain_tx_hash:
          <<84, 133, 148, 16, 138, 47, 89, 9, 12, 99, 34, 212, 19, 11, 55, 155, 143, 238, 249, 66, 56, 169, 15, 72, 105,
            33, 184, 110, 48, 23, 144, 38>>
      }

      assert {:ok, %{"deposit-blknum-3" => block}} = Deposit.callback([deposit_event])
      assert %Block{number: 3, state: "confirmed"} = block

      block = Repo.preload(block, :transactions)

      assert %Transaction{outputs: [output]} = hd(block.transactions)
      assert %Output{output_data: data} = output
      assert %ExPlasma.Output{output_data: %{amount: 1_000_000_000_000_000_000}} = ExPlasma.Output.decode(data)
    end
  end

  test "takes multiple deposit events" do
    deposit_events = [
      %{
        amount: 1_000_000_000_000_000_000,
        blknum: 6,
        currency: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
        eth_height: 406,
        event_signature: "DepositCreated(address,uint256,address,uint256)",
        log_index: 1,
        owner: <<64, 64, 241, 220, 12, 24, 243, 144, 146, 241, 28, 53, 165, 4, 54, 169, 145, 71, 180, 85>>,
        root_chain_tx_hash:
          <<191, 246, 172, 55, 42, 126, 149, 188, 255, 83, 244, 160, 188, 185, 201, 27, 233, 75, 169, 8, 119, 161, 147,
            41, 211, 49, 109, 57, 127, 103, 30, 201>>
      },
      %{
        amount: 1_000_000_000_000_000_000,
        blknum: 5,
        currency: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
        eth_height: 406,
        event_signature: "DepositCreated(address,uint256,address,uint256)",
        log_index: 0,
        owner: <<55, 1, 205, 186, 148, 200, 85, 8, 213, 44, 97, 189, 196, 39, 129, 163, 245, 230, 23, 206>>,
        root_chain_tx_hash:
          <<64, 27, 200, 238, 249, 169, 198, 242, 109, 48, 50, 67, 31, 41, 151, 149, 123, 75, 245, 129, 30, 47, 40, 235,
            10, 1, 129, 162, 25, 167, 144, 253>>
      }
    ]

    assert {:ok, %{"deposit-blknum-6" => block6, "deposit-blknum-5" => block5}} = Deposit.callback(deposit_events)
    assert %Block{number: 6, state: "confirmed"} = block6
    assert %Block{number: 5, state: "confirmed"} = block5
  end

  test "does not re-insert existing deposit events" do
    deposit_events = [
      %{
        amount: 1_000_000_000_000_000_000,
        blknum: 11,
        currency: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
        eth_height: 406,
        event_signature: "DepositCreated(address,uint256,address,uint256)",
        log_index: 1,
        owner: <<64, 64, 241, 220, 12, 24, 243, 144, 146, 241, 28, 53, 165, 4, 54, 169, 145, 71, 180, 85>>,
        root_chain_tx_hash:
          <<191, 246, 172, 55, 42, 126, 149, 188, 255, 83, 244, 160, 188, 185, 201, 27, 233, 75, 169, 8, 119, 161, 147,
            41, 211, 49, 109, 57, 127, 103, 30, 201>>
      },
      %{
        amount: 1_000_000_000_000_000_000,
        blknum: 12,
        currency: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
        eth_height: 406,
        event_signature: "DepositCreated(address,uint256,address,uint256)",
        log_index: 0,
        owner: <<55, 1, 205, 186, 148, 200, 85, 8, 213, 44, 97, 189, 196, 39, 129, 163, 245, 230, 23, 206>>,
        root_chain_tx_hash:
          <<64, 27, 200, 238, 249, 169, 198, 242, 109, 48, 50, 67, 31, 41, 151, 149, 123, 75, 245, 129, 30, 47, 40, 235,
            10, 1, 129, 162, 25, 167, 144, 253>>
      }
    ]

    new_deposit_events = [
      %{
        amount: 1_000_000_000_000_000_000,
        blknum: 13,
        currency: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
        eth_height: 406,
        event_signature: "DepositCreated(address,uint256,address,uint256)",
        log_index: 0,
        owner: <<55, 1, 205, 186, 148, 200, 85, 8, 213, 44, 97, 189, 196, 39, 129, 163, 245, 230, 23, 206>>,
        root_chain_tx_hash:
          <<64, 27, 200, 238, 249, 169, 198, 242, 109, 48, 50, 67, 31, 41, 151, 149, 123, 75, 245, 129, 30, 47, 40, 235,
            10, 1, 129, 162, 25, 167, 144, 253>>
      }
    ]

    assert {:ok, %{"deposit-blknum-11" => _, "deposit-blknum-12" => _}} = Deposit.callback(deposit_events)
    assert {:ok, %{"deposit-blknum-13" => _}} = Deposit.callback(deposit_events ++ new_deposit_events)
    assert 3 == Repo.one(from(b in Engine.DB.Block, select: count(b.id)))
  end
end
