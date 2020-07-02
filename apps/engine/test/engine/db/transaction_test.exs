defmodule Engine.DB.TransactionTest do
  use Engine.DB.DataCase, async: true
  doctest Engine.DB.Transaction, import: true

  alias Engine.DB.Output
  alias Engine.DB.Transaction
  alias Engine.Support.TestEntity
  alias ExPlasma.Builder

  describe "decode/2" do
    test "decodes tx_bytes and validates for a deposit" do
      %{tx_bytes: tx_bytes} = build(:deposit_transaction, amount: 0)
      changeset = Transaction.decode(tx_bytes, kind: Transaction.kind_deposit())

      refute changeset.valid?
      assert assert "can not be zero" in errors_on(changeset).amount
    end

    test "decodes tx_bytes and validates for a transfer" do
      tx_bytes =
        [tx_type: 1]
        |> Builder.new()
        |> Builder.add_input(blknum: 1, txindex: 0, oindex: 0)
        |> Builder.add_output(output_guard: <<1::160>>, token: <<0::160>>, amount: 0)
        |> ExPlasma.encode()

      changeset = Transaction.decode(tx_bytes, kind: Transaction.kind_transfer())

      refute changeset.valid?
      assert assert "can not be zero" in errors_on(changeset).amount
      assert assert "inputs [1000000000] are missing, spent, or not yet available" in errors_on(changeset).inputs
    end

    test "casts and validate required fields" do
      tx_bytes =
        [tx_type: 1]
        |> Builder.new()
        |> Builder.add_input(blknum: 1, txindex: 0, oindex: 0)
        |> Builder.add_output(output_guard: <<1::160>>, token: <<0::160>>, amount: 1)
        |> ExPlasma.encode()

      changeset = Transaction.decode(tx_bytes, kind: Transaction.kind_transfer())

      assert get_field(changeset, :tx_type) == 1
      assert get_field(changeset, :kind) == Transaction.kind_transfer()
      assert get_field(changeset, :tx_bytes) == tx_bytes
    end

    test "builds the outputs" do
      input_blknum = 1
      insert(:output, %{blknum: input_blknum, state: "confirmed"})

      o_1_data = [token: <<0::160>>, amount: 10, output_guard: <<1::160>>]
      o_2_data = [token: <<0::160>>, amount: 10, output_guard: <<1::160>>]

      tx_bytes =
        [tx_type: 1]
        |> Builder.new()
        |> Builder.add_input(blknum: input_blknum, txindex: 0, oindex: 0)
        |> Builder.add_output(o_1_data)
        |> Builder.add_output(o_2_data)
        |> ExPlasma.encode()

      changeset = Transaction.decode(tx_bytes, kind: Transaction.kind_transfer())

      assert [%Output{output_data: o_1_data_enc}, %Output{output_data: o_2_data_enc}] = get_field(changeset, :outputs)
      assert ExPlasma.Output.decode(o_1_data_enc).output_data == Enum.into(o_1_data, %{})
      assert ExPlasma.Output.decode(o_2_data_enc).output_data == Enum.into(o_1_data, %{})
    end

    test "builds the inputs" do
      input_blknum = 1
      input = insert(:output, %{blknum: input_blknum, state: "confirmed"})

      tx_bytes =
        [tx_type: 1]
        |> Builder.new()
        |> Builder.add_input(blknum: input_blknum, txindex: 0, oindex: 0)
        |> Builder.add_output(output_guard: <<1::160>>, token: <<0::160>>, amount: 10)
        |> ExPlasma.encode()

      changeset = Transaction.decode(tx_bytes, kind: Transaction.kind_transfer())

      assert get_field(changeset, :inputs) == [input]
    end

    test "is valid when inputs are signed correctly" do
      %{priv_encoded: priv_encoded, addr: addr} = TestEntity.alice()

      data = %{output_guard: addr, token: <<0::160>>, amount: 10}
      insert(:output, %{output_data: data, blknum: 1, state: "confirmed"})
      insert(:output, %{output_data: data, blknum: 2, state: "confirmed"})

      tx_bytes =
        [tx_type: 1]
        |> Builder.new()
        |> Builder.add_input(blknum: 1, txindex: 0, oindex: 0)
        |> Builder.add_input(blknum: 2, txindex: 0, oindex: 0)
        |> Builder.add_output(output_guard: <<1::160>>, token: <<0::160>>, amount: 20)
        |> Builder.sign([priv_encoded, priv_encoded])
        |> ExPlasma.encode()

      changeset = Transaction.decode(tx_bytes, kind: Transaction.kind_transfer())

      assert changeset.valid?
    end

    test "builds the tx_hash" do
      input_blknum = 1
      insert(:output, %{blknum: input_blknum, state: "confirmed"})

      tx_bytes =
        [tx_type: 1]
        |> Builder.new()
        |> Builder.add_input(blknum: input_blknum, txindex: 0, oindex: 0)
        |> Builder.add_output(output_guard: <<1::160>>, token: <<0::160>>, amount: 10)
        |> ExPlasma.encode()

      changeset = Transaction.decode(tx_bytes, kind: Transaction.kind_transfer())
      tx_hash = ExPlasma.hash(tx_bytes)

      assert get_field(changeset, :tx_hash) == tx_hash
    end
  end

  describe "pending/0" do
    test "get all pending transactions" do
    end
  end

  describe "find_by_tx_hash/0" do
    test "get transaction matching the hash" do
    end
  end
end
