defmodule Engine.DB.Transaction2Test do
  use ExUnit.Case, async: true
  doctest Engine.DB.Transaction2, import: true
  import Engine.Factory

  alias Engine.DB.Transaction2, as: Transaction
  alias Engine.DB.Output

  describe "changeset/2" do

    test "validates the transactions with the stateless protocol" do
      params = params_for(:deposit, %{amount: 0})
      changeset = Transaction.changeset(%Transaction{}, params)

      refute changeset.valid?
      assert {"can not be zero", []} = changeset.errors[:amount]
    end

    test "builds the inputs" do
      params = params_for(:deposit, %{amount: 1})
      changeset = Transaction.changeset(%Transaction{}, params)

      assert %Output{} = hd(changeset.changes.outputs).data
    end

    test "builds the outputs" do
      params = params_for(:payment_v1, %{amount: 1})
      changeset = Transaction.changeset(%Transaction{}, params)

      assert %Output{} = hd(changeset.changes.inputs).data
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
