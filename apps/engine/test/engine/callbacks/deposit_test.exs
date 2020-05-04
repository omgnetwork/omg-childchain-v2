defmodule Engine.Callbacks.DepositTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Engine.Callbacks.Deposit

  describe "deposit/2" do
    # test "generates a confirmed transaction, block and utxo for the deposit" do
    #   deposit_event = %{
    #     data: %{
    #       "amount" => 1_000_000_000_000_000_000,
    #       "blknum" => 3,
    #       "token" => <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
    #       "depositor" => <<55, 1, 205, 186, 148, 200, 85, 8, 213, 44, 97, 189, 196, 39, 129, 163, 245, 230, 23, 206>>
    #     },
    #     eth_height: 404,
    #     event_signature: "DepositCreated(address,uint256,address,uint256)",
    #     log_index: 1,
    #     root_chain_tx_hash:
    #       <<84, 133, 148, 16, 138, 47, 89, 9, 12, 99, 34, 212, 19, 11, 55, 155, 143, 238, 249, 66, 56, 169, 15, 72, 105,
    #         33, 184, 110, 48, 23, 144, 38>>
    #   }

    #   assert {:ok, %{"deposit-blknum-3" => transaction}} = Deposit.callback([deposit_event], :depositor)
    #   assert transaction.block.number == 3

    #   assert %Engine.SyncedHeight{height: 404, listener: "depositor"} =
    #            Engine.Repo.get(Engine.SyncedHeight, "#{:depositor}")
    # end

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
            <<84, 133, 148, 16, 138, 47, 89, 9, 12, 99, 34, 212, 19, 11, 55, 155, 143, 238, 249, 66, 56, 169, 15, 72,
              105, 33, 184, 110, 48, 23, 144, 38>>
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
            <<84, 133, 148, 16, 138, 47, 89, 9, 12, 99, 34, 212, 19, 11, 55, 155, 143, 238, 249, 66, 56, 169, 15, 72,
              105, 33, 184, 110, 48, 23, 144, 38>>
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
            <<84, 133, 148, 16, 138, 47, 89, 9, 12, 99, 34, 212, 19, 11, 55, 155, 143, 238, 249, 66, 56, 169, 15, 72,
              105, 33, 184, 110, 48, 23, 144, 38>>
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
            <<84, 133, 148, 16, 138, 47, 89, 9, 12, 99, 34, 212, 19, 11, 55, 155, 143, 238, 249, 66, 56, 169, 15, 72,
              105, 33, 184, 110, 48, 23, 144, 38>>
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
            <<84, 133, 148, 16, 138, 47, 89, 9, 12, 99, 34, 212, 19, 11, 55, 155, 143, 238, 249, 66, 56, 169, 15, 72,
              105, 33, 184, 110, 48, 23, 144, 38>>
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
            <<84, 133, 148, 16, 138, 47, 89, 9, 12, 99, 34, 212, 19, 11, 55, 155, 143, 238, 249, 66, 56, 169, 15, 72,
              105, 33, 184, 110, 48, 23, 144, 38>>
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
            <<84, 133, 148, 16, 138, 47, 89, 9, 12, 99, 34, 212, 19, 11, 55, 155, 143, 238, 249, 66, 56, 169, 15, 72,
              105, 33, 184, 110, 48, 23, 144, 38>>
        }
      ]

      assert {:ok, _} = Deposit.callback(deposit_events_listener1, :depositor)

      assert [
               %Engine.Transaction{
                 block_id: 1,
                 id: 1,
                 metadata:
                   <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
                 tx_data: 0,
                 tx_type: 1
               },
               %Engine.Transaction{
                 block_id: 2,
                 id: 2,
                 metadata:
                   <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
                 tx_data: 0,
                 tx_type: 1
               }
             ] = Engine.Repo.all(Engine.Transaction)

      assert %Engine.SyncedHeight{height: 405, listener: "depositor"} =
               Engine.Repo.get(Engine.SyncedHeight, "#{:depositor}")

      assert {:ok, _} = Deposit.callback(deposit_events_listener2, :depositor)

      assert [
               %Engine.Transaction{
                 block_id: 1,
                 id: 1,
                 metadata:
                   <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
                 tx_data: 0,
                 tx_type: 1
               },
               %Engine.Transaction{
                 block_id: 2,
                 id: 2,
                 metadata:
                   <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
                 tx_data: 0,
                 tx_type: 1
               },
               %Engine.Transaction{
                 block_id: 3,
                 id: 3,
                 metadata:
                   <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
                 tx_data: 0,
                 tx_type: 1
               }
             ] = Engine.Repo.all(Engine.Transaction)

      assert %Engine.SyncedHeight{height: 406, listener: "depositor"} =
               Engine.Repo.get(Engine.SyncedHeight, "#{:depositor}")

      assert {:ok, _} = Deposit.callback(deposit_events_listener3, :depositor)

      assert [
               %Engine.Transaction{
                 block_id: 1,
                 id: 1,
                 metadata:
                   <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
                 tx_data: 0,
                 tx_type: 1
               },
               %Engine.Transaction{
                 block_id: 2,
                 id: 2,
                 metadata:
                   <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
                 tx_data: 0,
                 tx_type: 1
               },
               %Engine.Transaction{
                 block_id: 3,
                 id: 3,
                 metadata:
                   <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
                 tx_data: 0,
                 tx_type: 1
               }
             ] = Engine.Repo.all(Engine.Transaction)

      assert %Engine.SyncedHeight{height: 406, listener: "depositor"} =
               Engine.Repo.get(Engine.SyncedHeight, "#{:depositor}")
    end
  end
end
