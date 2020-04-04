defmodule Engine.BlockTest do
  use ExUnit.Case, async: true
  doctest Engine.Block

  import Engine.Factory
  import Ecto.Query, only: [from: 2]

  alias Engine.Block

  describe "form_block/0" do
    test "forms a block from the existing pending transactions" do
      insert(:transaction)
      insert(:transaction)

      {:ok, {block_id, total_records}} = Block.form_block()

      query = from(t in Engine.Transaction, where: t.block_id == ^block_id)
      size = query |> Engine.Repo.all() |> length()

      assert size == 2
      assert total_records == size
    end
  end
end
