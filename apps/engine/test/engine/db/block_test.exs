defmodule Engine.DB.BlockTest do
  use ExUnit.Case, async: true
  doctest Engine.DB.Block, import: true

  import Engine.Factory
  import Ecto.Query, only: [from: 2]

  alias Engine.DB.Block

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Engine.Repo)
  end

  describe "form_block/0" do
    test "forms a block from the existing pending transactions" do
      insert(:deposit_transaction, %{amount: 1})
      insert(:deposit_transaction, %{amount: 1})

      {:ok, {block_id, total_records}} = Block.form_block()

      query = from(t in Engine.DB.Transaction, where: t.block_id == ^block_id)
      size = query |> Engine.Repo.all() |> length()

      assert size == 2
      assert total_records == size
    end
  end
end
