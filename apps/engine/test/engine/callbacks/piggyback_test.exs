defmodule Engine.Callbacks.PiggybackTest do
  @moduledoc false
  use Engine.DB.DataCase, async: true
  alias Engine.Callbacks.Piggyback
  alias Engine.DB.ListenerState
  alias Engine.DB.Output
  alias Engine.Repo

  setup do
    _ = insert(:fee, hash: "10", term: :no_fees_required, type: :merged_fees)

    :ok
  end

  describe "callback/2" do
    test "marks an input as piggybacked" do
      %{inputs: [input]} = transaction = insert(:payment_v1_transaction)
      assert input.state == "confirmed"

      events = [build(:input_piggyback_event, tx_hash: transaction.tx_hash, input_index: 0, height: 405)]
      key = "piggyback-#{transaction.tx_hash}-inputs-#{input.position}"

      assert {:ok, %{^key => input}} = Piggyback.callback(events, :piggybacker)
      assert input.state == "piggybacked"
      assert listener_for(:piggybacker, height: 405)
    end

    test "marks an output as piggybacked" do
      %{outputs: [output]} = transaction = insert(:payment_v1_transaction)
      output |> change(state: "confirmed") |> Repo.update()

      events = [build(:output_piggyback_event, tx_hash: transaction.tx_hash, output_index: 0, height: 404)]
      key = "piggyback-#{transaction.tx_hash}-outputs-#{output.position}"

      assert {:ok, %{^key => output}} = Piggyback.callback(events, :piggybacker)
      assert output.state == "piggybacked"
      assert listener_for(:piggybacker, height: 404)
    end

    test "doesn't mark input as piggyback if its unusable" do
      %{inputs: [input]} = transaction = insert(:payment_v1_transaction)
      input |> change(state: "spent") |> Repo.update()

      events = [build(:input_piggyback_event, tx_hash: transaction.tx_hash, input_index: 0, height: 404)]

      assert {:ok, multi} = Piggyback.callback(events, :piggybacker)
      refute is_map_key(multi, "piggyback-#{transaction.tx_hash}-inputs-#{input.position}")
      assert Repo.get(Output, input.id).state == "spent"
      assert listener_for(:piggybacker, height: 404)
    end

    test "doesn't mark output as piggyback if its unusable" do
      %{outputs: [output]} = transaction = insert(:payment_v1_transaction)
      output |> change(state: "exited") |> Repo.update()

      events = [build(:input_piggyback_event, tx_hash: transaction.tx_hash, output_index: 0, height: 404)]

      assert {:ok, multi} = Piggyback.callback(events, :piggybacker)
      refute is_map_key(multi, "piggyback-#{transaction.tx_hash}-outputs-#{output.position}")
      assert Repo.get(Output, output.id).state == "exited"
      assert listener_for(:piggybacker, height: 404)
    end

    test "returns {:ok, :noop} when no event given" do
      assert Piggyback.callback([], :piggybacker) == {:ok, :noop}
    end
  end

  # Check to see if the listener has a given state, like height.
  #   assert listener_for(:depositor, height: 100)
  defp listener_for(listener, height: height) do
    name = "#{listener}"
    %ListenerState{height: ^height, listener: ^name} = Engine.Repo.get(ListenerState, name)
  end
end
