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

  test "generates a confirmed transaction, block and utxo for the deposit" do
    deposit_event = build(:deposit_event, amount: 1, blknum: 3, depositor: <<1::160>>)

    assert {:ok, %{"deposit-output-3000000000" => %Output{} = output}} = Deposit.callback([deposit_event], :depositor)

    assert ExPlasma.Output.decode!(output.output_data) == %ExPlasma.Output{
             output_data: %{amount: 1, token: <<0::160>>, output_guard: <<1::160>>},
             output_type: 1
           }

    assert ExPlasma.Output.decode_id!(output.output_id) == %ExPlasma.Output{
             output_id: %{blknum: 3, txindex: 0, oindex: 0, position: output.position}
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

    assert Output |> Repo.all() |> Enum.count() == 2
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

    assert Output |> Repo.all() |> Enum.count() == 2

    assert {:ok, %{"deposit-output-5000000000" => _}} = Deposit.callback(deposit_events_listener2, :depositor)

    assert listener_for(:depositor, height: 406)

    assert Output |> Repo.all() |> Enum.count() == 3

    assert {:ok, _} = Deposit.callback(deposit_events_listener3, :depositor)

    assert listener_for(:depositor, height: 406)

    assert Output |> Repo.all() |> Enum.count() == 3

    assert {:ok, _} = Deposit.callback(deposit_events_listener3, :depositor)

    assert listener_for(:depositor, height: 406)
  end

  # Check to see if the listener has a given state, like height.
  #   assert listener_for(:depositor, height: 100)
  defp listener_for(listener, height: height) do
    name = "#{listener}"
    %ListenerState{height: ^height, listener: ^name} = Engine.Repo.get(ListenerState, name)
  end
end
