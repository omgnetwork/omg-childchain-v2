defmodule Engine.DB.Block.BlockQueryTest do
  use Engine.DB.DataCase, async: false

  alias Engine.DB.Block
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
      block1 = insert(:block, %{state: Block.state_finalizing()})
      block2 = insert(:block)

      max_nonce = Repo.one!(BlockQuery.select_max_nonce())
      assert block1.nonce < max_nonce
      assert block2.nonce == max_nonce
    end
  end

  describe "get_all_for_submission/2" do
    test "filters by new height - submitted at ethereum height is not nil" do
      block1 = insert(:block, %{state: Block.state_finalizing(), submitted_at_ethereum_height: 1})
      _ = insert(:block, %{submitted_at_ethereum_height: 2})

      [block] = Repo.all(BlockQuery.get_all_for_submission(2, 0))
      assert block1.id == block.id
    end

    test "filters by new height - submitted at ethereum height is nil and there is a block pending submission" do
      _ = insert(:block, %{state: Block.state_pending_submission(), submitted_at_ethereum_height: 1})
      block2 = insert(:block, %{state: Block.state_pending_submission(), submitted_at_ethereum_height: nil})

      [block] = Repo.all(BlockQuery.get_all_for_submission(0, 0))
      assert block2.id == block.id
    end

    test "filters by new height - submitted at ethereum height is nil and there are no blocks pending submission" do
      _ = insert(:block, %{state: Block.state_pending_submission(), submitted_at_ethereum_height: 1})
      _ = insert(:block, %{state: Block.state_forming(), submitted_at_ethereum_height: nil})
      _ = insert(:block, %{state: Block.state_finalizing(), submitted_at_ethereum_height: nil})

      assert [] == Repo.all(BlockQuery.get_all_for_submission(0, 0))
    end

    test "filters by child block number" do
      block1 = insert(:block, %{state: Block.state_finalizing()})
      block2 = insert(:block, %{state: Block.state_pending_submission()})

      [block] = Repo.all(BlockQuery.get_all_for_submission(2, block1.blknum))
      assert block2.id == block.id
    end

    test "result is ordered by nonce" do
      _ = insert(:block, %{state: Block.state_finalizing()})
      _ = insert(:block)

      [b1, b2] = Repo.all(BlockQuery.get_all_for_submission(2, 0))

      assert b1.blknum < b2.blknum
    end
  end

  describe "select_finalizing_blocks/0" do
    test "selects all finalizing blocks" do
      block_finalizing1 = insert(:block, %{state: Block.state_finalizing()})
      block_finalizing2 = insert(:block, %{state: Block.state_finalizing()})
      _ = insert(:block, %{state: Block.state_forming()})
      _ = insert(:block, %{state: Block.state_pending_submission()})
      _ = insert(:block, %{state: Block.state_submitted()})
      _ = insert(:block, %{state: Block.state_confirmed()})

      assert [selected_block1, selected_block2] = Repo.all(BlockQuery.select_finalizing_blocks())
      assert block_finalizing1.id == selected_block1.id
      assert block_finalizing2.id == selected_block2.id
    end
  end

  describe "get_last_formed_block_eth_height/0" do
    test "returns last formed block ethereum height" do
      _ = insert(:block, %{formed_at_ethereum_height: 10, state: Block.state_finalizing()})
      _ = insert(:block, %{formed_at_ethereum_height: 20, state: Block.state_finalizing()})
      assert Repo.one!(BlockQuery.get_last_formed_block_eth_height()) == 20
    end
  end
end
