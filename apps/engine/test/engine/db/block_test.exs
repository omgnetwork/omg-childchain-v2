defmodule Engine.DB.BlockTest do
  use Engine.DB.DataCase, async: true
  import Ecto.Query, only: [from: 2]

  alias Ecto.Adapters.SQL.Sandbox
  alias Engine.DB.Block
  alias Engine.DB.Transaction
  alias Engine.Repo
  alias ExPlasma.Merkle

  describe "form/0" do
    test "forms a block from the existing pending transactions" do
      _ = insert(:payment_v1_transaction)
      {:ok, %{"new-block" => block}} = Block.form()
      transactions = Repo.all(from(t in Transaction, where: t.block_id == ^block.id))

      assert length(transactions) == 1
    end

    test "generates the block hash" do
      txn1 = insert(:payment_v1_transaction)
      hash = Merkle.root_hash([Transaction.encode_unsigned(txn1)])

      assert {:ok, %{"hash-block" => block}} = Block.form()
      assert block.hash == hash
    end

    test "correctly generates block hash for empty txs list" do
      assert {:ok, %{"hash-block" => block}} = Block.form()

      assert block.hash ==
               <<246, 9, 190, 253, 254, 144, 102, 254, 20, 231, 67, 179, 98, 62, 174, 135, 143, 188, 70, 128, 5, 96,
                 136, 22, 131, 44, 157, 70, 15, 42, 149, 210>>
    end

    test "block hash is consistent with childchain v1" do
      alice_priv_key =
        "0x" <>
          Base.encode16(
            <<54, 43, 207, 67, 140, 160, 190, 135, 18, 162, 70, 120, 36, 245, 106, 165, 5, 101, 183, 55, 11, 117, 126,
              135, 49, 50, 12, 228, 173, 219, 183, 175>>,
            case: :lower
          )

      bob_address = <<207, 194, 79, 222, 88, 128, 171, 217, 153, 41, 195, 239, 138, 178, 227, 16, 72, 173, 118, 35>>

      Enum.each(0..1, fn index ->
        tx_bytes =
          ExPlasma.payment_v1()
          |> ExPlasma.Builder.new()
          |> ExPlasma.Builder.add_input(blknum: 1, txindex: index, oindex: index)
          |> ExPlasma.Builder.add_output(
            output_type: 1,
            output_data: %{output_guard: bob_address, token: <<0::160>>, amount: 100}
          )
          |> ExPlasma.Builder.sign!([alice_priv_key])
          |> ExPlasma.encode!()

        _ = insert(:payment_v1_transaction, tx_bytes: tx_bytes)
      end)

      assert {:ok, %{"hash-block" => block}} = Block.form()

      assert block.hash ==
               <<189, 245, 69, 5, 94, 45, 148, 210, 5, 89, 98, 245, 201, 111, 222, 48, 61, 114, 145, 55, 122, 84, 196,
                 156, 254, 80, 85, 184, 3, 205, 163, 233>>
    end

    @tag timeout: :infinity
    @tag :integration
    test "correctly calculates hash for a lot of transactions" do
      alice_priv_key =
        "0x" <>
          Base.encode16(
            <<54, 43, 207, 67, 140, 160, 190, 135, 18, 162, 70, 120, 36, 245, 106, 165, 5, 101, 183, 55, 11, 117, 126,
              135, 49, 50, 12, 228, 173, 219, 183, 175>>,
            case: :lower
          )

      bob_address = <<207, 194, 79, 222, 88, 128, 171, 217, 153, 41, 195, 239, 138, 178, 227, 16, 72, 173, 118, 35>>

      Enum.each(1..64_000, fn index ->
        tx_bytes =
          ExPlasma.payment_v1()
          |> ExPlasma.Builder.new()
          |> ExPlasma.Builder.add_input(blknum: 1, txindex: index, oindex: index)
          |> ExPlasma.Builder.add_output(
            output_type: 1,
            output_data: %{output_guard: bob_address, token: <<0::160>>, amount: 100}
          )
          |> ExPlasma.Builder.sign!([alice_priv_key])
          |> ExPlasma.encode!()

        _ = insert(:payment_v1_transaction, tx_bytes: tx_bytes)
      end)

      assert {:ok, %{"hash-block" => block}} = Block.form()

      assert block.hash ==
               <<12, 40, 202, 7, 16, 175, 119, 138, 7, 95, 8, 3, 148, 93, 162, 168, 136, 226, 196, 236, 83, 62, 220, 75,
                 59, 52, 6, 18, 249, 52, 124, 228>>
    end

    test "assigns nonce and blknum" do
      _ = insert(:payment_v1_transaction)

      assert {:ok, %{"hash-block" => block}} = Block.form()
      assert block.nonce == 1
      assert block.blknum == 1_000
    end

    test "autoincrements nonce and blknum" do
      assert {:ok, %{"hash-block" => block1}} = Block.form()
      assert block1.nonce == 1
      assert block1.blknum == 1_000

      _ = insert(:payment_v1_transaction)

      assert {:ok, %{"hash-block" => block2}} = Block.form()
      assert block2.nonce == 2
      assert block2.blknum == 2_000
    end
  end

  describe "insert/2" do
    test "fails to insert block when blknum != 1000 * nonce" do
      assert_raise Ecto.ConstraintError, ~r/block_number_nonce/, fn ->
        %Block{}
        |> Block.changeset(%{nonce: 1, blknum: 2000})
        |> Repo.insert()
      end
    end
  end

  describe "get_by_hash/2" do
    test "returns the block without preloads" do
      _ = insert(:payment_v1_transaction)
      {:ok, %{"hash-block" => block}} = Block.form()

      assert {:ok, block_result} = Block.get_by_hash(block.hash, [])
      refute Ecto.assoc_loaded?(block_result.transactions)
      assert block_result.hash == block.hash
    end

    test "returns the block with preloads" do
      %{tx_hash: tx_hash} = insert(:payment_v1_transaction)
      {:ok, %{"hash-block" => block}} = Block.form()

      assert {:ok, block_result} = Block.get_by_hash(block.hash, :transactions)
      assert [%{tx_hash: ^tx_hash}] = block_result.transactions
      assert block_result.hash == block.hash
    end

    test "returns {:error, :no_block_matching_hash} if not found" do
      assert {:error, :no_block_matching_hash} = Block.get_by_hash(<<0>>, [])
    end

    test "fails to insert two block with the same hash" do
      assert_raise Ecto.ConstraintError, ~r/blocks_hash_index/, fn ->
        _ = insert(:block, hash: "1", blknum: 2000, nonce: 2)
        _ = insert(:block, hash: "1", blknum: 5000, nonce: 5)
      end
    end
  end

  test "integration point is not called when there are no blocks to submit" do
    parent = self()

    integration = fn hash, nonce, gas ->
      Kernel.send(parent, {hash, nonce, gas})
    end

    assert Block.get_all_and_submit(1000, 1000, integration) == {:ok, %{compute_gas_and_submit: [], get_all: []}}
    refute_receive _
  end

  describe "this would be a normal case where a node sees some plasma blocks are not mined and adjust gas for those and re-submits them" do
    test "10 block in DB, 7 in ethereum, submit 3 in nonce order" do
      nonce = 1
      blknum = 1000

      # just insert 10 blocks that were created over 10 eth blocks
      _ =
        Enum.reduce(1..10, {nonce, blknum}, fn index, {nonce, blknum} ->
          insert(:block, %{
            nonce: nonce,
            blknum: blknum,
            submitted_at_ethereum_height: index,
            formed_at_ethereum_height: index,
            attempts_counter: 1
          })

          {nonce + 1, blknum + 1000}
        end)

      parent = self()
      # this would be our vault
      integration_point = fn hash, nonce, gas ->
        Kernel.send(parent, {hash, nonce, gas})
        :ok
      end

      # at this height, I'm looking at what was submitted and what wasn't
      # I notice  that blocks with blknum from 1000 to 7000 were mined but above that it needs a resubmission
      my_current_eth_height = 11
      mined_child_block = 7000

      {:ok, %{get_all: blocks}} = Block.get_all_and_submit(my_current_eth_height, mined_child_block, integration_point)

      assert [%{nonce: 8}, %{nonce: 9}, %{nonce: 10}] = blocks
      # assert that our integration point was called with these blocks
      [8, 9, 10] = receive_all_blocks()

      sql =
        from(plasma_block in Block,
          where: plasma_block.nonce == 8 or plasma_block.nonce == 9 or plasma_block.nonce == 10
        )

      sql
      |> Repo.all()
      |> Enum.each(fn block ->
        assert block.submitted_at_ethereum_height == my_current_eth_height
        assert block.attempts_counter == 2
      end)
    end
  end

  describe "(NEWLY FORMED BLOCK) this would be a normal case where a node sees some plasma blocks are not mined and adjust gas for those and re-submits them" do
    test "10 block in DB, 7 in ethereum, submit 3 in nonce order" do
      nonce = 1
      blknum = 1000

      # just insert 10 blocks that were created over 10 eth blocks
      _ =
        Enum.reduce(1..10, {nonce, blknum}, fn index, {nonce, blknum} ->
          insert(:block, %{
            nonce: nonce,
            blknum: blknum,
            submitted_at_ethereum_height: index,
            formed_at_ethereum_height: index,
            attempts_counter: 1
          })

          {nonce + 1, blknum + 1000}
        end)

      parent = self()
      # this would be our vault
      integration_point = fn hash, nonce, gas ->
        Kernel.send(parent, {hash, nonce, gas})
        :ok
      end

      # at this height, I'm looking at what was submitted and what wasn't
      # I notice  that blocks with blknum from 1000 to 7000 were mined but above that it needs a resubmission
      insert(:block, %{nonce: 11, blknum: 11_000, formed_at_ethereum_height: 11})

      my_current_eth_height = 11
      mined_child_block = 7000

      {:ok, %{get_all: blocks}} = Block.get_all_and_submit(my_current_eth_height, mined_child_block, integration_point)

      assert [%{nonce: 8}, %{nonce: 9}, %{nonce: 10}, %{nonce: 11}] = blocks
      # assert that our integration point was called with these blocks
      [8, 9, 10, 11] = receive_all_blocks()

      sql =
        from(plasma_block in Block,
          where:
            plasma_block.nonce == 8 or plasma_block.nonce == 9 or plasma_block.nonce == 10 or plasma_block.nonce == 11
        )

      sql
      |> Repo.all()
      |> Enum.each(fn block ->
        case block.nonce do
          11 ->
            assert block.attempts_counter == 1

          _ ->
            assert block.submitted_at_ethereum_height == my_current_eth_height
            assert block.attempts_counter == 2
        end
      end)
    end
  end

  describe "a node is behind (in terms of ethereum block height and other competing childchain nodes)" do
    test "10 block in DB, 7 in ethereum, don't submit anything because you're too far behind" do
      nonce = 1
      blknum = 1000

      # just insert 10 blocks that were created over 10 eth blocks
      _ =
        Enum.reduce(1..10, {nonce, blknum}, fn index, {nonce, blknum} ->
          insert(:block, %{
            nonce: nonce,
            blknum: blknum,
            submitted_at_ethereum_height: index,
            formed_at_ethereum_height: index
          })

          {nonce + 1, blknum + 1000}
        end)

      parent = self()
      # this would be our vault
      integration_point = fn hash, nonce, gas ->
        Kernel.send(parent, {hash, nonce, gas})
        :ok
      end

      # at this height, I'm looking at what was submitted and what wasn't
      # I notice  that blocks with blknum from 1000 to 7000 were mined but above that it needs a resubmission
      my_current_eth_height = 6
      mined_child_block = 6000

      {:ok, %{get_all: blocks}} = Block.get_all_and_submit(my_current_eth_height, mined_child_block, integration_point)

      assert [] = blocks
      # assert that our integration point was called with these blocks
      [] = receive_all_blocks()
    end
  end

  describe "block formed and submited at the current height is not re-submitted" do
    test "even though mined blocks shows less! this would be a case where a newly formed block was submitted by some other childchain node and not the current one" do
      nonce = 2
      blknum = 2000
      my_current_eth_height = 6

      # just insert 10 blocks that were created over 10 eth blocks

      insert(:block, %{
        nonce: nonce,
        blknum: blknum,
        submitted_at_ethereum_height: my_current_eth_height,
        formed_at_ethereum_height: my_current_eth_height
      })

      parent = self()
      # this would be our vault
      integration_point = fn hash, nonce, gas ->
        Kernel.send(parent, {hash, nonce, gas})
        :ok
      end

      # at this height, I'm looking at what was submitted and what wasn't
      # I notice  that blocks with blknum from 1000 to 7000 were mined but above that it needs a resubmission

      mined_child_block = 1000

      {:ok, %{get_all: blocks}} = Block.get_all_and_submit(my_current_eth_height, mined_child_block, integration_point)

      assert [] = blocks
      # assert that our integration point was called with these blocks
      [] = receive_all_blocks()
    end
  end

  describe "a simulation of multiple childchains accesing block submission" do
    test "processes try to re-submit blocks" do
      nonce = 1
      blknum = 1000

      # just insert 10 blocks that were created over 10 eth blocks
      _ =
        Enum.reduce(1..10, {nonce, blknum}, fn index, {nonce, blknum} ->
          insert(:block, %{
            nonce: nonce,
            blknum: blknum,
            submitted_at_ethereum_height: index,
            formed_at_ethereum_height: index,
            attempts_counter: 1
          })

          {nonce + 1, blknum + 1000}
        end)

      parent = self()
      # this would be our vault
      integration_point = fn hash, nonce, gas ->
        Kernel.send(parent, {hash, nonce, gas})
        :ok
      end

      # at this height, I'm looking at what was submitted and what wasn't
      # I notice  that blocks with blknum from 1000 to 7000 were mined but above that it needs a resubmission
      insert(:block, %{nonce: 11, blknum: 11_000, formed_at_ethereum_height: 11})

      my_current_eth_height = 11
      mined_child_block = 7000

      number_of_childchains = 10

      1..number_of_childchains
      |> Task.async_stream(
        fn _ ->
          Sandbox.allow(Engine.Repo, parent, self())
          Block.get_all_and_submit(my_current_eth_height, mined_child_block, integration_point)
        end,
        timeout: 5000,
        on_timeout: :kill_task,
        max_concurrency: System.schedulers_online()
      )
      |> Enum.map(fn {:ok, result} -> result end)

      # if submission was executed once, it was executed by one of the childchains
      # that WON the race, hence, we should receive nonces as messages only once
      [8, 9, 10, 11] = receive_all_blocks()
    end
  end

  defp receive_all_blocks() do
    receive_all_blocks([])
  end

  defp receive_all_blocks(acc) do
    receive do
      {_hash, nonce, _gas} -> receive_all_blocks([nonce | acc])
    after
      50 ->
        # list appending adds at the tail so we need to reverse it once done
        Enum.reverse(acc)
    end
  end
end
