defmodule Engine.DB.TransactionTest do
  use Engine.DB.DataCase, async: true
  doctest Engine.DB.Transaction, import: true

  alias Engine.DB.Output
  alias Engine.DB.Transaction
  alias Engine.Support.TestEntity
  alias ExPlasma.Builder

  setup_all do
    _ = insert(:fee, hash: "22", type: :merged_fees)

    :ok
  end

  describe "decode/2" do
    test "decodes tx_bytes and validates for a deposit" do
      %{tx_bytes: tx_bytes} = build(:deposit_transaction, amount: 0)
      {:ok, changeset} = Transaction.decode(tx_bytes, Transaction.kind_deposit())

      refute changeset.valid?
      assert assert "Cannot be zero" in errors_on(changeset).amount
    end

    test "decodes tx_bytes and validates for a transfer" do
      tx_bytes =
        ExPlasma.payment_v1()
        |> Builder.new()
        |> Builder.add_input(blknum: 1, txindex: 0, oindex: 0)
        |> Builder.add_output(output_guard: <<1::160>>, token: <<0::160>>, amount: 0)
        |> Builder.sign!([])
        |> ExPlasma.encode()

      assert {:ok, changeset} = Transaction.decode(tx_bytes, Transaction.kind_transfer())

      refute changeset.valid?
      assert assert "Cannot be zero" in errors_on(changeset).amount
      assert assert "inputs [1000000000] are missing, spent, or not yet available" in errors_on(changeset).inputs
    end

    test "casts and validate required fields" do
      tx_bytes =
        ExPlasma.payment_v1()
        |> Builder.new()
        |> Builder.add_input(blknum: 1, txindex: 0, oindex: 0)
        |> Builder.add_output(output_guard: <<1::160>>, token: <<0::160>>, amount: 1)
        |> Builder.sign!([])
        |> ExPlasma.encode()

      assert {:ok, changeset} = Transaction.decode(tx_bytes, Transaction.kind_transfer())

      signed_tx = get_field(changeset, :signed_tx)

      assert get_field(changeset, :tx_type) == 1
      assert get_field(changeset, :kind) == Transaction.kind_transfer()
      assert get_field(changeset, :tx_bytes) == tx_bytes
      assert get_field(changeset, :tx_hash) == ExPlasma.hash(signed_tx)
      assert get_field(changeset, :witnesses) == []
    end

    test "builds the outputs" do
      input_blknum = 1
      insert(:output, %{blknum: input_blknum, state: "confirmed"})

      o_1_data = [token: <<0::160>>, amount: 10, output_guard: <<1::160>>]
      o_2_data = [token: <<0::160>>, amount: 10, output_guard: <<1::160>>]

      tx_bytes =
        ExPlasma.payment_v1()
        |> Builder.new()
        |> Builder.add_input(blknum: input_blknum, txindex: 0, oindex: 0)
        |> Builder.add_output(o_1_data)
        |> Builder.add_output(o_2_data)
        |> Builder.sign!([])
        |> ExPlasma.encode()

      assert {:ok, changeset} = Transaction.decode(tx_bytes, Transaction.kind_transfer())

      assert [%Output{output_data: o_1_data_enc}, %Output{output_data: o_2_data_enc}] = get_field(changeset, :outputs)
      assert ExPlasma.Output.decode(o_1_data_enc).output_data == Enum.into(o_1_data, %{})
      assert ExPlasma.Output.decode(o_2_data_enc).output_data == Enum.into(o_1_data, %{})
    end

    test "builds the inputs" do
      input_blknum = 1
      input = insert(:output, %{blknum: input_blknum, state: "confirmed"})

      tx_bytes =
        ExPlasma.payment_v1()
        |> Builder.new()
        |> Builder.add_input(blknum: input_blknum, txindex: 0, oindex: 0)
        |> Builder.add_output(output_guard: <<1::160>>, token: <<0::160>>, amount: 10)
        |> Builder.sign!([])
        |> ExPlasma.encode()

      assert {:ok, changeset} = Transaction.decode(tx_bytes, Transaction.kind_transfer())

      assert get_field(changeset, :inputs) == [input]
    end

    test "is valid when inputs are signed correctly" do
      _ =
        insert(:fee,
          type: :merged_fees,
          term: :no_fees_required,
          inserted_at: DateTime.add(DateTime.utc_now(), 10_000_000, :second)
        )

      %{priv_encoded: priv_encoded_1, addr: addr_1} = TestEntity.alice()
      %{priv_encoded: priv_encoded_2, addr: addr_2} = TestEntity.bob()

      data_1 = %{output_guard: addr_1, token: <<0::160>>, amount: 10}
      data_2 = %{output_guard: addr_2, token: <<0::160>>, amount: 10}
      insert(:output, %{output_data: data_1, blknum: 1, state: "confirmed"})
      insert(:output, %{output_data: data_2, blknum: 2, state: "confirmed"})

      tx_bytes =
        ExPlasma.payment_v1()
        |> Builder.new()
        |> Builder.add_input(blknum: 1, txindex: 0, oindex: 0)
        |> Builder.add_input(blknum: 2, txindex: 0, oindex: 0)
        |> Builder.add_output(output_guard: <<1::160>>, token: <<0::160>>, amount: 20)
        |> Builder.sign!([priv_encoded_1, priv_encoded_2])
        |> ExPlasma.encode()

      assert {:ok, changeset} = Transaction.decode(tx_bytes, Transaction.kind_transfer())

      assert changeset.valid?
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
