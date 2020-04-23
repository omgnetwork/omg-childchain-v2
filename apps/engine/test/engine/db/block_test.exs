defmodule Engine.DB.BlockTest do
  use ExUnit.Case, async: true
  doctest Engine.Block, import: true

  import Engine.Factory
  import Ecto.Query, only: [from: 2]

  alias Engine.Block

  describe "form_block/0" do
    test "forms a block from the existing pending transactions" do
      insert(:payment_v1, %{blknum: 3, txindex: 0, oindex: 0, amount: 1})
      insert(:payment_v1, %{blknum: 4, txindex: 0, oindex: 0, amount: 1})

      {:ok, {block_id, total_records}} = Block.form_block()

      query = from(t in Engine.DB.Transaction, where: t.block_id == ^block_id)
      size = query |> Engine.Repo.all() |> length()

      assert size == 2
      assert total_records == size
    end
  end
end
