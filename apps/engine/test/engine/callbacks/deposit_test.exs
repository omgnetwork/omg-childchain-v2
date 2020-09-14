defmodule Engine.Callbacks.DepositTest do
  @moduledoc false

  use Engine.DB.DataCase, async: true

  alias Engine.Callbacks.Deposit
  alias Engine.DB.ListenerState
  alias Engine.DB.Output

  setup do
    _ = insert(:fee, type: :merged_fees)

    :ok
  end

  describe "callback/2" do
    test "generates a confirmed output for the deposit" do
      token = <<0::160>>
      depositor = <<1::160>>
      blknum = 3
      amount = 1

      deposit_event = build(:deposit_event, token: token, amount: amount, blknum: blknum, depositor: depositor)

      assert {:ok, %{"deposit-output-3000000000" => %Output{} = output}} = Deposit.callback([deposit_event], :depositor)

      assert ExPlasma.Output.decode!(output.output_data) == %ExPlasma.Output{
               output_data: %{amount: amount, token: token, output_guard: depositor},
               output_type: ExPlasma.payment_v1()
             }

      assert ExPlasma.Output.decode_id!(output.output_id) == %ExPlasma.Output{
               output_id: %{blknum: blknum, txindex: 0, oindex: 0, position: 3_000_000_000}
             }
    end

    test "takes multiple deposit events" do
      events = [
        build(:deposit_event, blknum: 6),
        build(:deposit_event, blknum: 5)
      ]

      assert {:ok,
              %{
                "deposit-output-6000000000" => %Output{},
                "deposit-output-5000000000" => %Output{}
              }} = Deposit.callback(events, :depositor)
    end

    test "does not re-insert existing deposit events" do
      event = build(:deposit_event, blknum: 1)
      events = [event, build(:deposit_event, blknum: 2)]

      assert {:ok, %{"deposit-output-1000000000" => _}} = Deposit.callback([event], :depositor)

      assert {:ok, %{"deposit-output-1000000000" => _, "deposit-output-2000000000" => _}} =
               Deposit.callback(events, :depositor)

      deposit_outputs = all_sorted_outputs()

      assert Enum.count(deposit_outputs) == 2
      assert Enum.at(deposit_outputs, 0).position == 1_000_000_000
      assert Enum.at(deposit_outputs, 1).position == 2_000_000_000
    end

    test "three listeners try to commit deposits from different starting heights" do
      deposit_events_listener1 = [
        build(:deposit_event, blknum: 3, height: 404),
        build(:deposit_event, blknum: 4, height: 405)
      ]

      deposit_events_listener2 = [
        build(:deposit_event, blknum: 3, height: 404),
        build(:deposit_event, blknum: 4, height: 405),
        build(:deposit_event, blknum: 5, height: 406)
      ]

      deposit_events_listener3 = [
        build(:deposit_event, blknum: 4, height: 405),
        build(:deposit_event, blknum: 5, height: 406)
      ]

      assert {:ok, %{"deposit-output-3000000000" => _, "deposit-output-4000000000" => _}} =
               Deposit.callback(deposit_events_listener1, :depositor)

      assert listener_for(:depositor, height: 405)

      deposit_outputs_1 = all_sorted_outputs()

      assert Enum.count(deposit_outputs_1) == 2
      assert Enum.at(deposit_outputs_1, 0).position == 3_000_000_000
      assert Enum.at(deposit_outputs_1, 1).position == 4_000_000_000

      assert {:ok, %{"deposit-output-5000000000" => _}} = Deposit.callback(deposit_events_listener2, :depositor)

      assert listener_for(:depositor, height: 406)

      deposit_outputs_2 = all_sorted_outputs()

      assert Enum.count(deposit_outputs_2) == 3
      assert Enum.at(deposit_outputs_2, 0).position == 3_000_000_000
      assert Enum.at(deposit_outputs_2, 1).position == 4_000_000_000
      assert Enum.at(deposit_outputs_2, 2).position == 5_000_000_000

      assert {:ok, _} = Deposit.callback(deposit_events_listener3, :depositor)

      assert listener_for(:depositor, height: 406)

      assert all_sorted_outputs() == deposit_outputs_2

      assert {:ok, _} = Deposit.callback(deposit_events_listener3, :depositor)

      assert all_sorted_outputs() == deposit_outputs_2
    end

    test "returns {:ok, :noop} when no event given" do
      assert Deposit.callback([], :depositor) == {:ok, :noop}
    end
  end

  # Check to see if the listener has a given state, like height.
  #   assert listener_for(:depositor, height: 100)
  defp listener_for(listener, height: height) do
    name = "#{listener}"
    %ListenerState{height: ^height, listener: ^name} = Engine.Repo.get(ListenerState, name)
  end

  defp all_sorted_outputs() do
    Output |> order_by(:position) |> select([:position]) |> Repo.all()
  end
end
