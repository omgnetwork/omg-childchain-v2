defmodule Engine.Callbacks.DepositTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Engine.Callbacks.Deposit

  describe "deposit/1" do
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

      assert {:ok, %{"deposit-blknum-3" => transaction}} = Deposit.callback([deposit_event], :depositor)
      assert transaction.block.number == 3

      assert %Engine.SyncedHeight{height: 404, listener: "depositor"} =
               Engine.Repo.get(Engine.SyncedHeight, "#{:depositor}")
    end
  end

  # test "takes multiple deposit events" do
  #   deposit_events = [
  #     %{
  #       data: %{
  #         "depositor" => <<64, 64, 241, 220, 12, 24, 243, 144, 146, 241, 28, 53, 165, 4, 54, 169, 145, 71, 180, 85>>,
  #         "amount" => 1_000_000_000_000_000_000,
  #         "blknum" => 6,
  #         "token" => <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
  #       },
  #       call_data: nil,
  #       eth_height: 406,
  #       event_signature: "DepositCreated(address,uint256,address,uint256)",
  #       log_index: 1,
  #       root_chain_tx_hash:
  #         <<191, 246, 172, 55, 42, 126, 149, 188, 255, 83, 244, 160, 188, 185, 201, 27, 233, 75, 169, 8,
  # 119, 161, 147,
  #           41, 211, 49, 109, 57, 127, 103, 30, 201>>
  #     },
  #     %{
  #       data: %{
  #         "amount" => 1_000_000_000_000_000_000,
  #         "blknum" => 5,
  #         "depositor" => <<55, 1, 205, 186, 148, 200, 85, 8, 213, 44, 97, 189, 196, 39, 129, 163, 245, 230, 23, 206>>,
  #         "token" => <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
  #       },
  #       eth_height: 406,
  #       event_signature: "DepositCreated(address,uint256,address,uint256)",
  #       log_index: 0,
  #       root_chain_tx_hash:
  #         <<64, 27, 200, 238, 249, 169, 198, 242, 109, 48, 50, 67, 31, 41, 151, 149, 123, 75, 245, 129, 30,
  # 47, 40, 235,
  #           10, 1, 129, 162, 25, 167, 144, 253>>
  #     }
  #   ]

  #   assert {:ok, %{"deposit-blknum-6" => transaction6, "deposit-blknum-5" => transaction5}} =
  #            Deposit.callback(deposit_events, :depositor)

  #   assert transaction5.block.number == 5
  #   assert transaction6.block.number == 6

  #   assert %Engine.SyncedHeight{height: 406, listener: "depositor"} =
  #            Engine.Repo.get(Engine.SyncedHeight, "#{:depositor}")
  # end

  test "takes multiple deposit events and merges them" do
    deposit_events1 = [
      %{
        data: %{
          "depositor" => <<64, 64, 241, 220, 12, 24, 243, 144, 146, 241, 28, 53, 165, 4, 54, 169, 145, 71, 180, 85>>,
          "amount" => 1_000_000_000_000_000_000,
          "blknum" => 6,
          "token" => <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
        },
        call_data: nil,
        eth_height: 406,
        event_signature: "DepositCreated(address,uint256,address,uint256)",
        log_index: 1,
        root_chain_tx_hash:
          <<191, 246, 172, 55, 42, 126, 149, 188, 255, 83, 244, 160, 188, 185, 201, 27, 233, 75, 169, 8, 119, 161, 147,
            41, 211, 49, 109, 57, 127, 103, 30, 201>>
      },
      %{
        data: %{
          "amount" => 1_000_000_000_000_000_000,
          "blknum" => 5,
          "depositor" => <<55, 1, 205, 186, 148, 200, 85, 8, 213, 44, 97, 189, 196, 39, 129, 163, 245, 230, 23, 206>>,
          "token" => <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
        },
        eth_height: 405,
        event_signature: "DepositCreated(address,uint256,address,uint256)",
        log_index: 0,
        root_chain_tx_hash:
          <<64, 27, 200, 238, 249, 169, 198, 242, 109, 48, 50, 67, 31, 41, 151, 149, 123, 75, 245, 129, 30, 47, 40, 235,
            10, 1, 129, 162, 25, 167, 144, 253>>
      }
    ]

    deposit_events2 = [
      %{
        data: %{
          "depositor" => <<64, 64, 241, 220, 12, 24, 243, 144, 146, 241, 28, 53, 165, 4, 54, 169, 145, 71, 180, 85>>,
          "amount" => 1_000_000_000_000_000_000,
          "blknum" => 7,
          "token" => <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
        },
        call_data: nil,
        eth_height: 407,
        event_signature: "DepositCreated(address,uint256,address,uint256)",
        log_index: 1,
        root_chain_tx_hash:
          <<191, 246, 172, 55, 42, 126, 149, 188, 255, 83, 244, 160, 188, 185, 201, 27, 233, 75, 169, 8, 119, 161, 147,
            41, 211, 49, 109, 57, 127, 103, 30, 201>>
      },
      %{
        data: %{
          "depositor" => <<64, 64, 241, 220, 12, 24, 243, 144, 146, 241, 28, 53, 165, 4, 54, 169, 145, 71, 180, 85>>,
          "amount" => 1_000_000_000_000_000_000,
          "blknum" => 6,
          "token" => <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
        },
        call_data: nil,
        eth_height: 406,
        event_signature: "DepositCreated(address,uint256,address,uint256)",
        log_index: 1,
        root_chain_tx_hash:
          <<191, 246, 172, 55, 42, 126, 149, 188, 255, 83, 244, 160, 188, 185, 201, 27, 233, 75, 169, 8, 119, 161, 147,
            41, 211, 49, 109, 57, 127, 103, 30, 201>>
      },
      %{
        data: %{
          "amount" => 1_000_000_000_000_000_000,
          "blknum" => 5,
          "depositor" => <<55, 1, 205, 186, 148, 200, 85, 8, 213, 44, 97, 189, 196, 39, 129, 163, 245, 230, 23, 206>>,
          "token" => <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
        },
        eth_height: 405,
        event_signature: "DepositCreated(address,uint256,address,uint256)",
        log_index: 0,
        root_chain_tx_hash:
          <<64, 27, 200, 238, 249, 169, 198, 242, 109, 48, 50, 67, 31, 41, 151, 149, 123, 75, 245, 129, 30, 47, 40, 235,
            10, 1, 129, 162, 25, 167, 144, 253>>
      }
    ]

    assert {:ok, %{"deposit-blknum-6" => transaction6, "deposit-blknum-5" => transaction5}} =
             Deposit.callback(deposit_events1, :depositor)

    # IO.inspect(Deposit.callback(deposit_events2, :depositor), label: "failure")

    assert transaction5.block.number == 5
    assert transaction6.block.number == 6

    assert %Engine.SyncedHeight{height: 407, listener: "depositor"} =
             Engine.Repo.get(Engine.SyncedHeight, "#{:depositor}")
  end
end
