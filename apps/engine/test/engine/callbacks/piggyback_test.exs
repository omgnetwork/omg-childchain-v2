defmodule Engine.Callbacks.PiggybackTest do
  @moduledoc false
  use Engine.DB.DataCase, async: true
  alias Engine.Callbacks.Piggyback
  alias Engine.DB.ListenerState

  setup_all do
    _ = insert(:fee, hash: "10", term: :no_fees_required, type: :merged_fees)

    :ok
  end

  test "marks an output as piggybacked" do
    deposit = insert(:deposit_transaction)
    output = hd(deposit.outputs)
    events = [build(:output_piggyback_event, tx_hash: deposit.tx_hash, output_index: 0, height: 404)]
    key = "piggyback-outputs-#{output.position}"

    assert {:ok, %{^key => output}} = Piggyback.callback(events, :piggybacker)
    assert output.state == "piggybacked"
    assert listener_for(:piggybacker, height: 404)
  end

  test "marks an input as piggybacked" do
    _ = insert(:deposit_transaction)
    transaction = insert(:payment_v1_transaction)
    input = hd(transaction.inputs)
    events = [build(:input_piggyback_event, tx_hash: transaction.tx_hash, input_index: 0, height: 405)]
    key = "piggyback-inputs-#{input.position}"

    assert {:ok, %{^key => input}} = Piggyback.callback(events, :piggybacker)
    assert input.state == "piggybacked"
    assert listener_for(:piggybacker, height: 405)
  end

  test "doesn't mark input as piggyback if its unusable" do
    _ = insert(:deposit_transaction)
    transaction = insert(:payment_v1_transaction)
    input = hd(transaction.inputs)

    input |> change(state: "spent") |> Engine.Repo.update()

    events = [build(:input_piggyback_event, tx_hash: transaction.tx_hash, input_index: 0, height: 404)]

    assert {:ok, %{}} = Piggyback.callback(events, :piggybacker)
    assert listener_for(:piggybacker, height: 404)
  end

  test "doesn't mark output as piggyback if its unusable" do
    _ = insert(:deposit_transaction)
    transaction = insert(:payment_v1_transaction)
    output = hd(transaction.outputs)

    output |> change(state: "exited") |> Engine.Repo.update()

    events = [build(:input_piggyback_event, tx_hash: transaction.tx_hash, output_index: 0, height: 404)]

    assert {:ok, %{}} = Piggyback.callback(events, :piggybacker)
    assert listener_for(:piggybacker, height: 404)
  end

  # Check to see if the listener has a given state, like height.
  #   assert listener_for(:depositor, height: 100)
  defp listener_for(listener, height: height) do
    name = "#{listener}"
    %ListenerState{height: ^height, listener: ^name} = Engine.Repo.get(ListenerState, name)
  end
end
