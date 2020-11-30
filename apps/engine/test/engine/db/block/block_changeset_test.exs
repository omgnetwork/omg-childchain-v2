defmodule Engine.DB.Block.BlockChangesetTest do
  use Engine.DB.DataCase, async: true

  alias Ecto.Changeset
  alias Engine.DB.Block
  alias Engine.DB.Block.BlockChangeset

  describe "new_block_changeset/2" do
    test "returns a proper block changeset" do
      hash = "0x0"
      tx_hash = "0x0"
      formed_at_ethereum_height = 1
      submitted_at_ethereum_height = 2
      gas = 1
      attempts_counter = 1
      nonce = 1
      blknum = 1_000
      state = Block.state_forming()

      changeset =
        BlockChangeset.new_block_changeset(%Block{}, %{
          hash: hash,
          tx_hash: tx_hash,
          formed_at_ethereum_height: formed_at_ethereum_height,
          submitted_at_ethereum_height: submitted_at_ethereum_height,
          gas: gas,
          attempts_counter: attempts_counter,
          nonce: nonce,
          blknum: blknum,
          state: state
        })

      assert changeset.valid?

      assert %Block{
               hash: ^hash,
               tx_hash: ^tx_hash,
               formed_at_ethereum_height: ^formed_at_ethereum_height,
               submitted_at_ethereum_height: ^submitted_at_ethereum_height,
               gas: ^gas,
               attempts_counter: ^attempts_counter,
               nonce: ^nonce,
               blknum: ^blknum,
               state: ^state
             } = Changeset.apply_changes(changeset)
    end

    test "returns invalid changeset when a required param is missing" do
      any_valid? =
        [
          %{blknum: 1_000, state: :forming},
          %{nonce: 1, state: :forming},
          %{nonce: 1, blknum: 1_000}
        ]
        |> Enum.map(fn params -> BlockChangeset.new_block_changeset(%Block{}, params) end)
        |> Enum.any?(fn changeset -> changeset.valid? end)

      refute any_valid?
    end
  end

  describe "submitted/2" do
    test "sets state, gas, attempts counter and submitted height" do
      params = %{gas: 1, attempts_counter: 2, submitted_at_ethereum_height: 3}
      changeset = BlockChangeset.submitted(%Block{}, params)

      assert changeset.valid?

      expected_state = Block.state_submitted()

      assert %Block{
               gas: 1,
               attempts_counter: 2,
               submitted_at_ethereum_height: 3,
               state: ^expected_state
             } = Changeset.apply_changes(changeset)
    end
  end

  describe "prepare_for_submission/2" do
    test "sets hash, state and formed ethereum height" do
      block = insert(:block)
      hash = "0xf"
      eth_height = 10

      changeset = BlockChangeset.prepare_for_submission(block, %{hash: hash, formed_at_ethereum_height: eth_height})

      assert changeset.valid?

      expected_state = Block.state_pending_submission()

      assert %Block{
               hash: ^hash,
               state: ^expected_state,
               formed_at_ethereum_height: ^eth_height
             } = Changeset.apply_changes(changeset)
    end
  end

  describe "finalize/1" do
    test "sets state to finalizing" do
      block = insert(:block)
      changeset = BlockChangeset.finalize(block)

      assert changeset.valid?

      expected_state = Block.state_finalizing()

      assert %Block{
               state: ^expected_state
             } = Changeset.apply_changes(changeset)
    end
  end
end
