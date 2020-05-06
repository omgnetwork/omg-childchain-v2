defmodule Engine.DB.TransactionTest do
  use Engine.DB.DataCase, async: true
  doctest Engine.DB.Transaction, import: true

  alias Engine.DB.Block
  alias Engine.DB.Output
  alias Engine.DB.Transaction

  describe "decode/1" do
    test "decodes tx_bytes and validates" do
      params = build(:deposit_transaction, amount: 0)
      changeset = Transaction.decode(params.tx_bytes)

      refute changeset.valid?
      assert {"can not be zero", []} = changeset.errors[:amount]
    end

    test "builds the outputs" do
      transaction = build(:deposit_transaction)
      assert %Output{} = hd(transaction.outputs)
    end

    test "builds the inputs" do
      transaction = build(:payment_v1_transaction)
      assert %Output{} = hd(transaction.inputs)
    end

    test "validates inputs exist" do
      transaction = build(:payment_v1_transaction)
      changeset = Transaction.decode(transaction.tx_bytes)

      refute changeset.valid?
      assert {"input 1000000000 are missing or spent", _} = changeset.errors[:inputs]
    end

    test "validates inputs are not spent" do
      %Transaction{block: %Block{number: number}} =
        :deposit_transaction
        |> build()
        |> spent()
        |> insert()

      transaction = build(:payment_v1_transaction, blknum: number)
      changeset = Transaction.decode(transaction.tx_bytes)

      refute changeset.valid?
      assert {"input 1000000000 are missing or spent", _} = changeset.errors[:inputs]
    end

    test "validates inputs are usable" do
      _ = insert(:deposit_transaction)
      transaction = build(:payment_v1_transaction)
      changeset = Transaction.decode(transaction.tx_bytes)

      assert changeset.valid?
    end

    test "references existing inputs" do
      %Transaction{outputs: [output]} = insert(:deposit_transaction)
      %Transaction{tx_bytes: tx_bytes} = build(:payment_v1_transaction)

      changeset = Transaction.decode(tx_bytes)
      input = changeset |> get_field(:inputs) |> hd()

      assert changeset.valid?
      assert output.id == input.id
    end

    test "builds the tx_hash" do
      _ = insert(:deposit_transaction)
      transaction = build(:payment_v1_transaction)
      changeset = Transaction.decode(transaction.tx_bytes)
      tx_hash = ExPlasma.hash(transaction.tx_bytes)

      assert changeset.valid?
      assert tx_hash == get_field(changeset, :tx_hash)
    end
  end
end
