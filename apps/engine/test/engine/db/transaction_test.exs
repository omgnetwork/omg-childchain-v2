defmodule Engine.DB.TransactionTest do
  use ExUnit.Case, async: true
  doctest Engine.DB.Transaction, import: true

  import Engine.DB.Factory

  alias Engine.DB.{Block, Output, Transaction}

  @moduletag :focus

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Engine.Repo)
  end

  describe "changeset/2" do

    test "builds the outputs" do
      transaction = build(:deposit_transaction)
      assert %Output{} = hd(transaction.outputs)
    end

    test "builds the inputs" do
      transaction = build(:payment_v1_transaction)
      assert %Output{} = hd(transaction.inputs)
    end

    test "validates the transactions with the stateless protocol" do
      transaction = build(:deposit_transaction, amount: 0)
      changeset = Transaction.decode_changeset(transaction.txbytes)

      refute changeset.valid?
      assert {"can not be zero", _} = changeset.errors[:amount]
    end

    test "validates inputs exist" do
      transaction = build(:payment_v1_transaction)
      changeset = Transaction.decode_changeset(transaction.txbytes)

      refute changeset.valid?
      assert {"input utxos 1000000000 are missing or spent", _} = changeset.errors[:inputs]
    end

    test "validates inputs are not spent" do
      %Transaction{block: %Block{number: number}} =
        :deposit_transaction 
        |> build()
        |> spent()
        |> insert()

      transaction = build(:payment_v1_transaction, blknum: number)
      changeset = Transaction.decode_changeset(transaction.txbytes)

      refute changeset.valid?
      assert {"input utxos 1000000000 are missing or spent", _} = changeset.errors[:inputs]
    end

    test "validates inputs are usable" do
      _ = insert(:deposit_transaction)
      transaction = build(:payment_v1_transaction)
      changeset = Transaction.decode_changeset(transaction.txbytes)

      assert changeset.valid?
    end

    test "references existing inputs" do
      deposit = insert(:deposit_transaction)
      transaction = build(:payment_v1_transaction)
      changeset = Transaction.decode_changeset(transaction.txbytes)

      #assert changeset.valid?
      #assert hd(changeset.data.inputs).id
    end
  end

  describe "decode_changeset/2" do
    test "decodes txbytes and validates" do
      params = params_for(:deposit_transaction, amount: 0)
      changeset = Transaction.decode_changeset(params.txbytes)

      refute changeset.valid?
      assert {"can not be zero", []} = changeset.errors[:amount]
    end
  end
end
