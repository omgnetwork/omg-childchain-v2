defmodule Engine.Callbacks.PiggybackTest do
  @moduledoc false
  use Engine.DB.DataCase, async: true
  alias Engine.Callbacks.Piggyback
  alias Engine.DB.ListenerState

  test "marks an output as piggybacked" do
    owner = <<180, 121, 214, 88, 10, 185, 115, 237, 127, 113, 101, 78, 28, 82, 108, 57, 64, 154, 219, 241>>
    deposit = insert(:deposit_transaction, output_guard: owner)
    output = hd(deposit.outputs)

    event = %{
      data: %{
        "tx_hash" => deposit.tx_hash,
        "output_index" => 0
      },
      eth_height: 404,
      event_signature: "InFlightExitOutputPiggybacked(address,bytes32,uint16)",
      log_index: 1,
      root_chain_tx_hash:
        <<84, 133, 148, 16, 138, 47, 89, 9, 12, 99, 34, 212, 19, 11, 55, 155, 143, 238, 249, 66, 56, 169, 15, 72, 105,
          33, 184, 110, 48, 23, 144, 38>>
    }

    key = "piggyback-outputs-#{output.position}"
    assert {:ok, %{^key => output}} = Piggyback.callback([event], :piggybacker)
    assert output.state == "piggybacked"

    assert %ListenerState{height: 404, listener: "piggybacker"} = Repo.get(ListenerState, "piggybacker")
  end

  test "marks an input as piggybacked" do
    owner = <<180, 121, 214, 88, 10, 185, 115, 237, 127, 113, 101, 78, 28, 82, 108, 57, 64, 154, 219, 241>>
    _ = insert(:deposit_transaction, output_guard: owner)
    transaction = insert(:payment_v1_transaction)
    input = hd(transaction.inputs)

    event = %{
      data: %{
        "tx_hash" => transaction.tx_hash,
        "input_index" => 0
      },
      eth_height: 404,
      event_signature: "InFlightExitInputPiggybacked(address,bytes32,uint16)",
      log_index: 1,
      root_chain_tx_hash:
        <<84, 133, 148, 16, 138, 47, 89, 9, 12, 99, 34, 212, 19, 11, 55, 155, 143, 238, 249, 66, 56, 169, 15, 72, 105,
          33, 184, 110, 48, 23, 144, 38>>
    }

    key = "piggyback-inputs-#{input.position}"
    assert {:ok, %{^key => input}} = Piggyback.callback([event], :piggybacker)
    assert input.state == "piggybacked"

    assert %ListenerState{height: 404, listener: "piggybacker"} = Repo.get(ListenerState, "piggybacker")
  end

  test "doesn't mark input as piggyback if its unusable" do
    owner = <<180, 121, 214, 88, 10, 185, 115, 237, 127, 113, 101, 78, 28, 82, 108, 57, 64, 154, 219, 241>>
    _ = insert(:deposit_transaction, output_guard: owner)
    transaction = insert(:payment_v1_transaction)
    input = hd(transaction.inputs)

    input |> change(state: "spent") |> Engine.Repo.update()

    event = %{
      data: %{
        "tx_hash" => transaction.tx_hash,
        "input_index" => 0
      },
      eth_height: 404,
      event_signature: "InFlightExitInputPiggybacked(address,bytes32,uint16)",
      log_index: 1,
      root_chain_tx_hash:
        <<84, 133, 148, 16, 138, 47, 89, 9, 12, 99, 34, 212, 19, 11, 55, 155, 143, 238, 249, 66, 56, 169, 15, 72, 105,
          33, 184, 110, 48, 23, 144, 38>>
    }

    assert {:ok, %{}} = Piggyback.callback([event], :piggybacker)

    assert %ListenerState{height: 404, listener: "piggybacker"} = Engine.Repo.get(ListenerState, "piggybacker")
  end

  test "doesn't mark output as piggyback if its unusable" do
    owner = <<180, 121, 214, 88, 10, 185, 115, 237, 127, 113, 101, 78, 28, 82, 108, 57, 64, 154, 219, 241>>
    _ = insert(:deposit_transaction, output_guard: owner)
    transaction = insert(:payment_v1_transaction)
    output = hd(transaction.outputs)

    output |> change(state: "exited") |> Engine.Repo.update()

    event = %{
      data: %{
        "tx_hash" => transaction.tx_hash,
        "output_index" => 0
      },
      eth_height: 404,
      event_signature: "InFlightExitOutputPiggybacked(address,bytes32,uint16)",
      log_index: 1,
      root_chain_tx_hash:
        <<84, 133, 148, 16, 138, 47, 89, 9, 12, 99, 34, 212, 19, 11, 55, 155, 143, 238, 249, 66, 56, 169, 15, 72, 105,
          33, 184, 110, 48, 23, 144, 38>>
    }

    assert {:ok, %{}} = Piggyback.callback([event], :piggybacker)

    assert %ListenerState{height: 404, listener: "piggybacker"} = Engine.Repo.get(ListenerState, "piggybacker")
  end
end
