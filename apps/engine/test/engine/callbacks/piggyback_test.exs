defmodule Engine.Callbacks.PiggybackTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Engine.DB.Factory
  import Ecto.Query
  import Ecto.Changeset

  alias Ecto.Adapters.SQL.Sandbox
  alias Engine.Callbacks.Piggyback
  alias Engine.DB.Output
  alias Engine.Repo

  setup do
    :ok = Sandbox.checkout(Repo)
  end

  describe "callback/1" do
    test "marks an output as piggybacked" do
      owner = <<180, 121, 214, 88, 10, 185, 115, 237, 127, 113, 101, 78, 28, 82, 108, 57, 64, 154, 219, 241>>
      deposit = insert(:deposit_transaction, output_guard: owner)
      output = hd(deposit.outputs)

      event = %{
        eth_height: 495,
        event_signature: "InFlightExitOutputPiggybacked(address,bytes32,uint16)",
        log_index: 1,
        omg_data: %{piggyback_type: :output},
        output_index: 0,
        owner: owner,
        root_chain_txhash:
          <<212, 219, 104, 41, 4, 36, 0, 15, 174, 188, 194, 119, 144, 2, 194, 146, 29, 58, 74, 12, 131, 195, 142, 160,
            155, 40, 118, 247, 141, 135, 74, 138>>,
        tx_hash: deposit.txhash
      }

      key = "piggyback-outputs-#{output.position}"
      assert {:ok, %{^key => output}} = Piggyback.callback([event])
      assert output.state == "piggybacked"
    end
  end

  test "marks an input as piggybacked" do
    owner = <<180, 121, 214, 88, 10, 185, 115, 237, 127, 113, 101, 78, 28, 82, 108, 57, 64, 154, 219, 241>>
    _ = insert(:deposit_transaction, output_guard: owner)
    transaction = insert(:payment_v1_transaction)
    input = hd(transaction.inputs)

    event = %{
      eth_height: 497,
      event_signature: "InFlightExitInputPiggybacked(address,bytes32,uint16)",
      log_index: 0,
      omg_data: %{piggyback_type: :input},
      output_index: 0,
      owner: owner,
      root_chain_txhash:
        <<40, 134, 206, 183, 182, 72, 20, 81, 62, 216, 72, 67, 230, 224, 13, 68, 105, 10, 217, 188, 142, 121, 93, 122,
          84, 202, 240, 9, 175, 223, 226, 12>>,
      tx_hash: transaction.txhash
    }

    key = "piggyback-inputs-#{input.position}"
    assert {:ok, %{^key => input}} = Piggyback.callback([event])
    assert input.state == "piggybacked"
  end

  test "doesn't mark input as piggyback if its unusable" do
    owner = <<180, 121, 214, 88, 10, 185, 115, 237, 127, 113, 101, 78, 28, 82, 108, 57, 64, 154, 219, 241>>
    _ = insert(:deposit_transaction, output_guard: owner)
    transaction = insert(:payment_v1_transaction)
    input = hd(transaction.inputs)

    input |> change(state: "spent") |> Engine.Repo.update()

    event = %{
      eth_height: 497,
      event_signature: "InFlightExitInputPiggybacked(address,bytes32,uint16)",
      log_index: 0,
      omg_data: %{piggyback_type: :input},
      output_index: 0,
      owner: owner,
      root_chain_txhash:
        <<40, 134, 206, 183, 182, 72, 20, 81, 62, 216, 72, 67, 230, 224, 13, 68, 105, 10, 217, 188, 142, 121, 93, 122,
          84, 202, 240, 9, 175, 223, 226, 12>>,
      tx_hash: transaction.txhash
    }

    assert {:ok, %{}} = Piggyback.callback([event])
  end

  test "doesn't mark output as piggyback if its unusable" do
    owner = <<180, 121, 214, 88, 10, 185, 115, 237, 127, 113, 101, 78, 28, 82, 108, 57, 64, 154, 219, 241>>
    _ = insert(:deposit_transaction, output_guard: owner)
    transaction = insert(:payment_v1_transaction)
    output = hd(transaction.outputs)

    output |> change(state: "exited") |> Engine.Repo.update()

    event = %{
      eth_height: 497,
      event_signature: "InFlightExitOutputPiggybacked(address,bytes32,uint16)",
      log_index: 0,
      omg_data: %{piggyback_type: :output},
      output_index: 0,
      owner: owner,
      root_chain_txhash:
        <<40, 134, 206, 183, 182, 72, 20, 81, 62, 216, 72, 67, 230, 224, 13, 68, 105, 10, 217, 188, 142, 121, 93, 122,
          84, 202, 240, 9, 175, 223, 226, 12>>,
      tx_hash: transaction.txhash
    }

    assert {:ok, %{}} = Piggyback.callback([event])
  end
end
