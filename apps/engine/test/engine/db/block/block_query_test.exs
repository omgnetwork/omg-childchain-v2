defmodule Engine.DB.Block.BlockQueryTest do
  use Engine.DB.DataCase, async: false

  alias Engine.DB.Block.BlockQuery
  alias Engine.Repo

  describe "select_forming_block_for_update/0" do
    test "selects forming block" do
      block = insert(:block)

      actual = Repo.one!(BlockQuery.select_forming_block_for_update())
      assert block.id == actual.id
    end
  end

  describe "select_max_nonce/0" do
    test "returns max nonce" do
      block1 = insert(:block, %{state: :finalizing})
      block2 = insert(:block)

      max_nonce = Repo.one!(BlockQuery.select_max_nonce())
      assert block1.nonce < max_nonce
      assert block2.nonce == max_nonce
    end
  end

  describe "get_all/2" do
    test "filters by new height - submitted at ethereum height is not nil" do
      block1 = insert(:block, %{state: :finalizing, submitted_at_ethereum_height: 1})
      _ = insert(:block, %{submitted_at_ethereum_height: 2})

      [block] = Repo.all(BlockQuery.get_all(2, 0))
      assert block1.id == block.id
    end

    test "filters by new height - submitted at ethereum height is nil" do
      _ = insert(:block, %{state: :finalizing, submitted_at_ethereum_height: 1})
      block2 = insert(:block, %{submitted_at_ethereum_height: nil})

      [block] = Repo.all(BlockQuery.get_all(0, 0))
      assert block2.id == block.id
    end

    test "filters by child block number" do
      block1 = insert(:block, %{state: :finalizing})
      block2 = insert(:block)

      [block] = Repo.all(BlockQuery.get_all(2, block1.blknum))
      assert block2.id == block.id
    end

    test "result is ordered by nonce" do
      _ = insert(:block, %{state: :finalizing})
      _ = insert(:block)

      [b1, b2] = Repo.all(BlockQuery.get_all(2, 0))

      assert b1.blknum < b2.blknum
    end
  end
end
