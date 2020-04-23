defmodule Engine.DB.TransactionTest do
  use ExUnit.Case, async: true
  doctest Engine.DB.Transaction, import: true
  import Engine.Factory

  alias Engine.DB.Transaction
  alias Engine.DB.Output

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Engine.Repo)
  end

  describe "changeset/2" do

    test "builds the outputs" do
      params = params_for(:deposit, %{amount: 1})
      changeset = Transaction.changeset(%Transaction{}, params)

      assert %Output{} = hd(changeset.changes.outputs).data
    end

    test "builds the inputs" do
      params = params_for(:payment_v1, %{amount: 1})
      changeset = Transaction.changeset(%Transaction{}, params)

      assert %Output{} = hd(changeset.changes.inputs).data
    end
    test "validates the transactions with the stateless protocol" do
      params = params_for(:deposit, %{amount: 0})
      changeset = Transaction.changeset(%Transaction{}, params)

      refute changeset.valid?
      assert {"can not be zero", _} = changeset.errors[:amount]
    end

    test "validates inputs exist" do
      params = params_for(:payment_v1, %{amount: 0})
      changeset = Transaction.changeset(%Transaction{}, params)

      refute changeset.valid?
      assert {"input utxos 1000000000 are missing or spent", _} = changeset.errors[:inputs]
    end

    test "validates inputs are not spent" do
      params = :input |> params_for(%{blknum: 1, txindex: 0, oindex: 0}) |> spent()
      {:ok, _} = %Output{} |> Output.changeset(params) |> Engine.Repo.insert()

      params = params_for(:payment_v1, %{amount: 1})
      changeset = Transaction.changeset(%Transaction{}, params)

      refute changeset.valid?
      assert {"input utxos 1000000000 are missing or spent", _} = changeset.errors[:inputs]
    end

    test "validates inputs are usable" do
      params = :input |> params_for(%{blknum: 2, txindex: 0, oindex: 0}) |> confirmed()
      {:ok, _} = %Output{} |> Output.changeset(params) |> Engine.Repo.insert()

      params = params_for(:payment_v1, %{blknum: 2, txindex: 0, oindex: 0, amount: 1})
      changeset = Transaction.changeset(%Transaction{}, params)

      assert changeset.valid?
    end
  end

  describe "decode_changeset/2" do
    test "decodes txbytes and validates" do
      params = params_for(:deposit, %{amount: 0})
      changeset = Transaction.decode_changeset(params.txbytes)

      refute changeset.valid?
      assert {"can not be zero", []} = changeset.errors[:amount]
    end
  end
end
