defmodule Engine.DB.BlockTest do
  use ExUnit.Case, async: true
  doctest Engine.DB.Block, import: true

  import Engine.DB.Factory
  import Ecto.Query, only: [from: 2]

  alias Ecto.Adapters.SQL.Sandbox
  alias Engine.DB.Block
  alias Engine.DB.Transaction
  alias Engine.Repo

  setup do
    :ok = Sandbox.checkout(Repo)
  end

  describe "form/0" do
    test "forms a block from the existing pending transactions" do
      _ = insert(:deposit_transaction)
      _ = insert(:payment_v1_transaction)

      assert = {:ok, %{"new-block" => block}} = Block.form()

      transactions = Engine.Repo.all(from(t in Transaction, where: t.block_id == ^block.id))

      assert 1 = length(transactions)
    end
  end
end
