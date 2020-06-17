defmodule Engine.DB.BlockTest do
  use Engine.DB.DataCase, async: true
  doctest Engine.DB.Block, import: true

  import Ecto.Query, only: [from: 2]

  alias Engine.DB.Block
  alias Engine.DB.Transaction

  describe "form/0" do
    test "forms a block from the existing pending transactions" do
      _ = insert(:deposit_transaction)
      _ = insert(:payment_v1_transaction)
      {:ok, %{"new-block" => block}} = Block.form()
      transactions = Engine.Repo.all(from(t in Transaction, where: t.block_id == ^block.id))

      assert length(transactions) == 1
    end

    test "generates the block hash" do
      _ = insert(:deposit_transaction)
      txn1 = insert(:payment_v1_transaction)
      hash = ExPlasma.Encoding.merkle_root_hash([txn1.tx_bytes])

      assert {:ok, %{"hash-block" => block}} = Block.form()
      assert block.hash == hash
    end
  end

  describe "query_by_hash/1" do
    test "returns the block" do
      _ = insert(:deposit_transaction)
      _ = insert(:payment_v1_transaction)
      {:ok, %{"hash-block" => block}} = Block.form()
      result = block.hash |> Block.query_by_hash() |> Engine.Repo.one()

      assert result.hash == block.hash
    end

    test "returns nil if no block" do
      result = <<0::160>> |> Block.query_by_hash() |> Engine.Repo.one()
      assert result == nil
    end
  end
end
