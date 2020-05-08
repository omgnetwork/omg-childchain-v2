defmodule Engine.Callbacks.DepositTest do
  @moduledoc false

  use Engine.DB.DataCase, async: true

  alias Engine.Callbacks.Deposit
  alias Engine.DB.Block
  alias Engine.DB.Output
  alias Engine.DB.Transaction

  test "generates a confirmed transaction, block and utxo for the deposit" do
    deposit_event = build(:deposit_event, amount: 1, blknum: 3, depositor: <<1::160>>)

    assert {:ok, %{"deposit-blknum-3" => block}} = Deposit.callback([deposit_event], :depositor)
    assert %Block{number: 3, state: "confirmed"} = block

    block = Repo.preload(block, :transactions)

    assert %Transaction{outputs: [output]} = hd(block.transactions)
    assert %Output{output_data: data} = output
    assert %ExPlasma.Output{output_data: %{amount: 1, output_guard: <<1::160>>}} = ExPlasma.Output.decode(data)
  end

  test "takes multiple deposit events" do
    events = [
      build(:deposit_event, blknum: 6),
      build(:deposit_event, blknum: 5)
    ]

    assert {:ok, %{"deposit-blknum-6" => block6, "deposit-blknum-5" => block5}} = Deposit.callback(events, :depositor)

    assert %Block{number: 6, state: "confirmed"} = block6
    assert %Block{number: 5, state: "confirmed"} = block5
  end

  test "does not re-insert existing deposit events" do
    event = build(:deposit_event, blknum: 1)
    events = [event, build(:deposit_event, blknum: 2)]

    assert {:ok, %{"deposit-blknum-1" => _}} = Deposit.callback([event], :depositor)
    assert {:ok, %{"deposit-blknum-1" => _, "deposit-blknum-2" => _}} = Deposit.callback(events, :depositor)
    assert Repo.one(from(b in Engine.DB.Block, select: count(b.id))) == 2
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

    assert {:ok, %{"deposit-blknum-3" => _, "deposit-blknum-4" => _}} =
             Deposit.callback(deposit_events_listener1, :depositor)

    assert listener_for(:depositor, height: 405)

    assert Repo.one(from(b in Engine.DB.Block, select: count(b.id))) == 2

    assert {:ok, %{"deposit-blknum-5" => _}} = Deposit.callback(deposit_events_listener2, :depositor)

    assert listener_for(:depositor, height: 406)

    assert Repo.one(from(b in Engine.DB.Block, select: count(b.id))) == 3

    assert {:ok, _} = Deposit.callback(deposit_events_listener3, :depositor)

    assert listener_for(:depositor, height: 406)

    assert Repo.one(from(b in Engine.DB.Block, select: count(b.id))) == 3

    assert {:ok, _} = Deposit.callback(deposit_events_listener3, :depositor)

    assert listener_for(:depositor, height: 406)
  end
end
