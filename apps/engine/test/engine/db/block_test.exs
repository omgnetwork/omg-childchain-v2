defmodule Engine.DB.BlockTest do
  use ExUnit.Case, async: true
  doctest Engine.DB.Block, import: true

  import Engine.DB.Factory
  import Ecto.Query, only: [from: 2]

  alias Engine.DB.Block
  alias Engine.DB.Transaction

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Engine.Repo)
  end

  describe "form_block/0" do
    test "forms a block from the existing pending transactions" do
      _ = insert(:deposit_transaction)
      _ = insert(:payment_v1_transaction)

      assert = {:ok, %{"new-block" => block}} = Block.form()

      transactions = from(t in Transaction, where: t.block_id == ^block.id) |> Engine.Repo.all()

      assert 1 = length(transactions)
    end
  end
end
