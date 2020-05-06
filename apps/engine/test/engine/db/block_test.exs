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

      assert {:ok, %{"new-block" => block}} = Block.form()

      transactions = Engine.Repo.all(from(t in Transaction, where: t.block_id == ^block.id))

      assert length(transactions) == 1
    end
  end
end
