defmodule Engine.DB.Transaction.TransactionQueryTest do
  use Engine.DB.DataCase, async: false

  alias Engine.DB.Transaction.TransactionQuery
  alias Engine.Repo

  describe "select_max_tx_index_for_block/1" do
    test "returns the biggest transaction index for a block" do
      block = insert(:block)
      _ = insert(:payment_v1_transaction, %{block: block, tx_index: 0})
      _ = insert(:payment_v1_transaction, %{block: block, tx_index: 2})
      _ = insert(:payment_v1_transaction, %{block: block, tx_index: 1})

      assert [2] ==
               block.id
               |> TransactionQuery.select_max_tx_index_for_block()
               |> Repo.all()
    end
  end

  describe "fetch_transactions_from_block/1" do
    test "returns all transaction from the block" do
      block1 = insert(:block, %{state: :finalizing})
      tx = insert(:payment_v1_transaction, %{block: block1, tx_index: 0})

      block2 = insert(:block)
      _ = insert(:payment_v1_transaction, %{block: block2, tx_index: 0})

      [%{id: id}] =
        block1.id
        |> TransactionQuery.fetch_transactions_from_block()
        |> Repo.all()

      assert tx.id == id
    end

    test "returned transaction are sorted by index" do
      block = insert(:block)
      %{id: first} = insert(:payment_v1_transaction, %{block: block, tx_index: 0})
      %{id: last} = insert(:payment_v1_transaction, %{block: block, tx_index: 2})
      %{id: middle} = insert(:payment_v1_transaction, %{block: block, tx_index: 1})

      selected_ids =
        block.id
        |> TransactionQuery.fetch_transactions_from_block()
        |> Repo.all()
        |> Enum.map(fn %{id: id} -> id end)

      assert [first, middle, last] == selected_ids
    end
  end

  describe "select_pending/0" do
    test "get all pending transactions" do
      block = insert(:block)
      insert(:payment_v1_transaction)
      insert(:payment_v1_transaction)

      :payment_v1_transaction
      |> insert()
      |> change(block_id: block.id)
      |> Engine.Repo.update()

      pending_tx = Engine.Repo.all(TransactionQuery.select_pending())
      assert Enum.count(pending_tx) == 2
    end
  end

  describe "select_by_tx_hash/0" do
    test "get transaction matching the hash" do
      %{tx_hash: tx_hash} = insert(:payment_v1_transaction)
      insert(:payment_v1_transaction)

      assert %{tx_hash: ^tx_hash} = tx_hash |> TransactionQuery.select_by_tx_hash() |> Engine.Repo.one()
    end
  end
end
