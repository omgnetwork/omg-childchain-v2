defmodule Engine.DB.BlockTest do
  use Engine.DB.DataCase, async: true
  doctest Engine.DB.Block, import: true

  import Ecto.Query, only: [from: 2]

  alias Engine.DB.Block
  alias Engine.DB.Transaction
  alias Engine.Repo
  alias ExPlasma.Merkle

  describe "form/0" do
    test "forms a block from the existing pending transactions" do
      _ = insert(:deposit_transaction)
      _ = insert(:payment_v1_transaction)
      {:ok, %{"new-block" => block}} = Block.form()
      transactions = Repo.all(from(t in Transaction, where: t.block_id == ^block.id))

      assert length(transactions) == 1
    end

    test "generates the block hash" do
      _ = insert(:deposit_transaction)
      txn1 = insert(:payment_v1_transaction)
      hash = Merkle.root_hash([txn1.tx_bytes])

      assert {:ok, %{"hash-block" => block}} = Block.form()
      assert block.hash == hash
    end
  end

  describe "query_by_hash/1" do
    test "returns the block" do
      _ = insert(:deposit_transaction)
      _ = insert(:payment_v1_transaction)
      {:ok, %{"hash-block" => block}} = Block.form()
      result = block.hash |> Block.query_by_hash() |> Repo.one()

      assert result.hash == block.hash
    end

    test "returns nil if no block" do
      result = <<0::160>> |> Block.query_by_hash() |> Repo.one()
      assert result == nil
    end
  end

  describe "get_by_hash/2" do
    test "returns the block without preloads" do
      _ = insert(:payment_v1_transaction)
      {:ok, %{"hash-block" => block}} = Block.form()

      assert {:ok, block_result} = Block.get_by_hash(block.hash, [])
      refute Ecto.assoc_loaded?(block_result.transactions)
      assert block_result.hash == block.hash
    end

    test "returns the block with preloads" do
      %{tx_hash: tx_hash} = insert(:payment_v1_transaction)
      {:ok, %{"hash-block" => block}} = Block.form()

      assert {:ok, block_result} = Block.get_by_hash(block.hash, :transactions)
      assert [%{tx_hash: ^tx_hash}] = block_result.transactions
      assert block_result.hash == block.hash
    end

    test "returns {:error, nil} if not found" do
      assert {:error, nil} = Block.get_by_hash(<<0>>, [])
    end

    test "returns at most 1 result" do
      # This can be removed when enforcing block hash uniqueness
      %{hash: hash_1} = insert(:block, %{number: 1})
      %{hash: hash_2} = insert(:block, %{number: 2})
      assert hash_1 == hash_2

      assert {:ok, %{hash: ^hash_1}} = Block.get_by_hash(hash_1, [])
    end
  end
end
