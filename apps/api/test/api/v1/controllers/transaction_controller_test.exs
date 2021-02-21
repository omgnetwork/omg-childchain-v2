defmodule API.V1.Controllere.TransactionControllerTest do
  use Engine.DB.DataCase, async: false

  alias API.V1.Controller.TransactionController
  alias Engine.DB.Block
  alias Engine.DB.Transaction
  alias Engine.Support.TestEntity
  alias ExPlasma.Builder
  alias ExPlasma.Encoding

  setup do
    _ = insert(:merged_fee)
    block = insert(:block)

    {:ok, %{blknum: block.blknum}}
  end

  describe "submit/1" do
    test "after a block is formed, incoming transaction is associated with a new block", %{blknum: blknum} do
      {tx_bytes1, tx_hash1} = tx_bytes_and_hash()

      assert TransactionController.submit(tx_bytes1) ==
               {:ok, %{tx_hash: Encoding.to_hex(tx_hash1), blknum: blknum, tx_index: 0}}

      {tx_bytes2, tx_hash2} = tx_bytes_and_hash()

      assert TransactionController.submit(tx_bytes2) ==
               {:ok, %{tx_hash: Encoding.to_hex(tx_hash2), blknum: blknum, tx_index: 1}}

      {tx_bytes3, tx_hash3} = tx_bytes_and_hash()

      _ = Block.finalize_forming_block()
      expected_blknum = blknum + 1_000

      assert TransactionController.submit(tx_bytes3) ==
               {:ok, %{tx_hash: Encoding.to_hex(tx_hash3), blknum: expected_blknum, tx_index: 0}}
    end

    test "it raises an error if the transaction is invalid" do
      invalid_hex_tx_bytes =
        ExPlasma.payment_v1()
        |> Builder.new()
        |> Builder.add_output(output_guard: <<0::160>>, token: <<0::160>>, amount: 0)
        |> Builder.sign!([])
        |> ExPlasma.encode!()
        |> Encoding.to_hex()

      assert {:error, changeset} = TransactionController.submit(invalid_hex_tx_bytes)
      assert "Cannot be zero" in errors_on(changeset).amount
    end

    test "submits a merge transaction" do
      entity = TestEntity.alice()

      %{output_id: input_output_id1} = insert(:deposit_output, amount: 10, output_guard: entity.addr)
      %{output_id: input_output_id2} = insert(:deposit_output, amount: 5, output_guard: entity.addr)
      %{output_data: output_data} = build(:output, output_guard: entity.addr, amount: 15)

      transaction =
        Builder.new(ExPlasma.payment_v1(), %{
          inputs: [ExPlasma.Output.decode_id!(input_output_id1), ExPlasma.Output.decode_id!(input_output_id2)],
          outputs: [ExPlasma.Output.decode!(output_data)]
        })

      tx_bytes =
        transaction
        |> Builder.sign!([entity.priv_encoded, entity.priv_encoded])
        |> ExPlasma.encode!()
        |> Encoding.to_hex()

      {:ok, tx_hash} = ExPlasma.Transaction.hash(transaction)

      assert {:ok, transaction} = TransactionController.submit(tx_bytes)
      assert Encoding.to_hex(tx_hash) == transaction.tx_hash

      found_transaction = Transaction.get_by(%{tx_hash: tx_hash}, [:fees])
      assert [] == found_transaction.fees
    end
  end

  defp tx_bytes_and_hash() do
    entity = TestEntity.alice()

    %{output_id: input_output_id} = insert(:deposit_output, amount: 10, output_guard: entity.addr)
    %{output_data: output_data} = build(:output, output_guard: entity.addr, amount: 9)

    transaction =
      Builder.new(ExPlasma.payment_v1(), %{
        inputs: [ExPlasma.Output.decode_id!(input_output_id)],
        outputs: [ExPlasma.Output.decode!(output_data)]
      })

    tx_bytes =
      transaction
      |> Builder.sign!([entity.priv_encoded])
      |> ExPlasma.encode!()
      |> Encoding.to_hex()

    {:ok, tx_hash} = ExPlasma.Transaction.hash(transaction)

    {tx_bytes, tx_hash}
  end
end
