defmodule Engine.DB.BlockTest do
  use Engine.DB.DataCase, async: true
  doctest Engine.DB.Block, import: true

  import Ecto.Query, only: [from: 2]

  alias Engine.DB.Block
  alias Engine.DB.Transaction

  describe "submit_attempt/2" do
    test "builds a changeset with a new submission attempt" do
      _ = insert(:deposit_transaction)
      _ = insert(:payment_v1_transaction)

      assert {:ok, %{"new-block" => block}} = Block.form()

      block_changeset = Block.submit_attempt(block, %{gas: 1, height: 1})
      submission_changeset = hd(changeset.changes[:submissions])

      assert submission_changeset.changes[:gas] == 1
      assert submission_changeset.changes[:height] == 1
    end

    test "can add additional submissions" do
      _ = insert(:deposit_transaction)
      _ = insert(:payment_v1_transaction)

      assert {:ok, %{"new-block" => block}} = Block.form()

      {:ok, block1} =
        block
        |> Engine.Repo.preload(:transactions)
        |> Block.submit_attempt(%{gas: 1, height: 1})
        |> Engine.Repo.update()

      {:ok, block2} =
        block1
        |> Engine.Repo.preload(:transactions)
        |> Block.submit_attempt(%{gas: 2, height: 2})
        |> Engine.Repo.update()

      assert length(block2.submissions) == 2
    end
  end

  describe "form/0" do
    test "forms a block from the existing pending transactions" do
      _ = insert(:deposit_transaction)
      _ = insert(:payment_v1_transaction)

      assert {:ok, %{"new-block" => block}} = Block.form()

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
end
