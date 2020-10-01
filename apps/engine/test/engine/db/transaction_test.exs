defmodule Engine.DB.TransactionTest do
  use Engine.DB.DataCase, async: true
  doctest Engine.DB.Transaction, import: true

  alias Engine.DB.Output
  alias Engine.DB.Transaction
  alias Engine.Support.TestEntity
  alias ExPlasma.Builder

  setup do
    _ = insert(:merged_fee)

    :ok
  end

  describe "decode/2" do
    test "decodes tx_bytes and validates" do
      tx_bytes =
        ExPlasma.payment_v1()
        |> Builder.new()
        |> Builder.add_input(blknum: 1, txindex: 0, oindex: 0)
        |> Builder.add_output(output_guard: <<1::160>>, token: <<0::160>>, amount: 0)
        |> Builder.sign!([])
        |> ExPlasma.encode!()

      assert {:ok, changeset} = Transaction.decode(tx_bytes)

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
        |> ExPlasma.encode!()

      assert {:ok, changeset} = Transaction.decode(tx_bytes)

      signed_tx = get_field(changeset, :signed_tx)
      {:ok, hash} = ExPlasma.hash(signed_tx)

      assert get_field(changeset, :tx_type) == 1
      assert get_field(changeset, :tx_bytes) == tx_bytes
      assert get_field(changeset, :tx_hash) == hash
      assert get_field(changeset, :witnesses) == []
    end

    test "builds the outputs" do
      input_blknum = 1
      insert(:deposit_output, %{blknum: input_blknum})

      o_1_data = [token: <<0::160>>, amount: 10, output_guard: <<1::160>>]
      o_2_data = [token: <<0::160>>, amount: 10, output_guard: <<1::160>>]

      tx_bytes =
        ExPlasma.payment_v1()
        |> Builder.new()
        |> Builder.add_input(blknum: input_blknum, txindex: 0, oindex: 0)
        |> Builder.add_output(o_1_data)
        |> Builder.add_output(o_2_data)
        |> Builder.sign!([])
        |> ExPlasma.encode!()

      assert {:ok, changeset} = Transaction.decode(tx_bytes)

      assert [%Output{output_data: o_1_data_enc}, %Output{output_data: o_2_data_enc}] = get_field(changeset, :outputs)
      assert ExPlasma.Output.decode!(o_1_data_enc).output_data == Enum.into(o_1_data, %{})
      assert ExPlasma.Output.decode!(o_2_data_enc).output_data == Enum.into(o_1_data, %{})
    end

    test "builds the inputs" do
      input_blknum = 1
      assert %{id: id, state: :confirmed} = insert(:deposit_output, %{blknum: input_blknum})

      tx_bytes =
        ExPlasma.payment_v1()
        |> Builder.new()
        |> Builder.add_input(blknum: input_blknum, txindex: 0, oindex: 0)
        |> Builder.add_output(output_guard: <<1::160>>, token: <<0::160>>, amount: 10)
        |> Builder.sign!([])
        |> ExPlasma.encode!()

      assert {:ok, changeset} = Transaction.decode(tx_bytes)

      assert [spent_input] = get_field(changeset, :inputs)
      assert spent_input.id == id
      assert spent_input.state == :spent
    end

    test "is valid when inputs are signed correctly" do
      %{priv_encoded: priv_encoded_1, addr: addr_1} = TestEntity.alice()
      %{priv_encoded: priv_encoded_2, addr: addr_2} = TestEntity.bob()

      insert(:deposit_output, %{output_guard: addr_1, token: <<0::160>>, amount: 10, blknum: 1})
      insert(:deposit_output, %{output_guard: addr_2, token: <<0::160>>, amount: 10, blknum: 2})

      tx_bytes =
        ExPlasma.payment_v1()
        |> Builder.new()
        |> Builder.add_input(blknum: 1, txindex: 0, oindex: 0)
        |> Builder.add_input(blknum: 2, txindex: 0, oindex: 0)
        |> Builder.add_output(output_guard: <<1::160>>, token: <<0::160>>, amount: 19)
        |> Builder.sign!([priv_encoded_1, priv_encoded_2])
        |> ExPlasma.encode!()

      assert {:ok, changeset} = Transaction.decode(tx_bytes)
      assert changeset.valid?
    end
  end

  describe "get_by/2" do
    test "returns the transaction given a query and preloads" do
      %{id: id_1, inputs: [%{id: input_id}]} = insert(:payment_v1_transaction)
      %{tx_hash: tx_hash_2} = insert(:payment_v1_transaction)

      assert %{id: ^id_1, inputs: [%{id: ^input_id}]} = Transaction.get_by([id: id_1], :inputs)

      assert %{tx_hash: ^tx_hash_2, inputs: %Ecto.Association.NotLoaded{}} =
               Transaction.get_by([tx_hash: tx_hash_2], [])
    end
  end

  describe "query_pending/0" do
    test "get all pending transactions" do
      block = insert(:block)
      insert(:payment_v1_transaction)
      insert(:payment_v1_transaction)

      :payment_v1_transaction
      |> insert()
      |> change(block_id: block.id)
      |> Engine.Repo.update()

      pending_tx = Engine.Repo.all(Transaction.query_pending())
      assert Enum.count(pending_tx) == 2
    end
  end

  describe "query_by_tx_hash/0" do
    test "get transaction matching the hash" do
      %{tx_hash: tx_hash} = insert(:payment_v1_transaction)
      insert(:payment_v1_transaction)

      assert %{tx_hash: ^tx_hash} = tx_hash |> Transaction.query_by_tx_hash() |> Engine.Repo.one()
    end
  end
end
