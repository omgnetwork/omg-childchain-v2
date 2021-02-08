defmodule Engine.DB.BlockTest do
  use Engine.DB.DataCase, async: false
  import Ecto.Query, only: [from: 2]

  alias Ecto.Adapters.SQL.Sandbox
  alias Engine.Configuration
  alias Engine.DB.Block
  alias Engine.DB.Transaction
  alias Engine.DB.Transaction.TransactionQuery
  alias Engine.Repo
  alias ExPlasma.Merkle

  @eth <<0::160>>
  @other_token <<1::160>>
  @eth_height 2

  describe "insert/2" do
    test "fails to insert block when blknum != 1000 * (nonce + 1)" do
      assert_raise Ecto.ConstraintError, ~r/block_number_nonce/, fn ->
        %Block{}
        |> Block.BlockChangeset.new_block_changeset(%{nonce: 1, blknum: 1000, state: :forming})
        |> Repo.insert()
      end
    end
  end

  describe "get_by_hash/2" do

    test "returns the block with preloads" do
      %{tx_hash: tx_hash, block: block} = insert(:payment_v1_transaction, %{block: insert(:block)})

      assert {:ok, block_result} = Block.get_transactions_by_block_hash(block.hash)
      assert [%{tx_hash: ^tx_hash}] = block_result.transactions
      assert block_result.hash == block.hash
    end

    test "returns {:error, :no_block_matching_hash} if not found" do
      assert {:error, :no_block_matching_hash} = Block.get_transactions_by_block_hash(<<0>>)
    end

    test "fails to insert two block with the same hash" do
      assert_raise Ecto.ConstraintError, ~r/blocks_hash_index/, fn ->
        _ = insert(:block, hash: "1", blknum: 2000, nonce: 1)
        _ = insert(:block, hash: "1", blknum: 5000, nonce: 4)
      end
    end
  end

  test "integration point is not called when there are no blocks to submit" do
    parent = self()

    integration = fn hash, nonce, gas ->
      Kernel.send(parent, {hash, nonce, gas})
    end

    ref = make_ref()

    gas_integration = fn ->
      Kernel.send(parent, ref)
      1
    end

    assert Block.get_all_and_submit(1000, 1000, integration, gas_integration) ==
             {:ok, %{get_gas_and_submit: [], get_all: []}}

    refute_receive _
  end

  describe "this would be a normal case where a node sees some plasma blocks are not mined and adjust gas for those and re-submits them" do
    test "10 block in DB, 7 in ethereum, submit 3 in nonce order" do
      nonce = 0
      blknum = 1000

      # just insert 10 blocks that were created over 10 eth blocks
      _ =
        Enum.reduce(1..10, {nonce, blknum}, fn index, {nonce, blknum} ->
          insert(:block, %{
            nonce: nonce,
            blknum: blknum,
            state:
              if index < 8 do
                :confirmed
              else
                :pending_submission
              end,
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
        vault_response_mock()
      end

      ref = make_ref()

      gas_integration = fn ->
        Kernel.send(parent, ref)
        %{standard: 1}
      end

      # at this height, I'm looking at what was submitted and what wasn't
      # I notice  that blocks with blknum from 1000 to 7000 were mined but above that it needs a resubmission
      my_current_eth_height = 11
      mined_child_block = 7000

      {:ok, %{get_all: blocks}} =
        Block.get_all_and_submit(my_current_eth_height, mined_child_block, integration_point, gas_integration)

      assert [%{nonce: 7}, %{nonce: 8}, %{nonce: 9}] = blocks
      # assert that our integration point was called with these blocks
      ["7", "8", "9"] = receive_all_blocks_nonces()
      ^ref = get_gas_ref()

      sql =
        from(plasma_block in Block,
          where: plasma_block.nonce == 7 or plasma_block.nonce == 8 or plasma_block.nonce == 9
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
      nonce = 0
      blknum = 1000

      # just insert 10 blocks that were created over 10 eth blocks
      _ =
        Enum.reduce(1..10, {nonce, blknum}, fn index, {nonce, blknum} ->
          insert(:block, %{
            nonce: nonce,
            blknum: blknum,
            state:
              if index < 8 do
                :confirmed
              else
                :pending_submission
              end,
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
        {:ok, "0x254ea979ba78f6adec707a97bc2dab8612c52b9047ffd47c81c2575e2373b699"}
      end

      ref = make_ref()

      gas_integration = fn ->
        Kernel.send(parent, ref)
        %{standard: 1}
      end

      # at this height, I'm looking at what was submitted and what wasn't
      # I notice  that blocks with blknum from 1000 to 7000 were mined but above that it needs a resubmission
      insert(:block, %{nonce: 10, blknum: 11_000, formed_at_ethereum_height: 11})

      my_current_eth_height = 11
      mined_child_block = 7000

      {:ok, %{get_all: blocks}} =
        Block.get_all_and_submit(my_current_eth_height, mined_child_block, integration_point, gas_integration)

      assert [%{nonce: 7}, %{nonce: 8}, %{nonce: 9}, %{nonce: 10}] = blocks
      # assert that our integration point was called with these blocks
      ["7", "8", "9", "10"] = receive_all_blocks_nonces()
      ^ref = get_gas_ref()

      sql =
        from(plasma_block in Block,
          where:
            plasma_block.nonce == 7 or plasma_block.nonce == 8 or plasma_block.nonce == 9 or plasma_block.nonce == 10
        )

      sql
      |> Repo.all()
      |> Enum.each(fn block ->
        case block.nonce do
          10 ->
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
      nonce = 0
      blknum = 1000

      # just insert 10 blocks that were created over 10 eth blocks
      _ =
        Enum.reduce(1..10, {nonce, blknum}, fn index, {nonce, blknum} ->
          insert(:block, %{
            nonce: nonce,
            blknum: blknum,
            state:
              if index < 8 do
                :confirmed
              else
                :pending_submission
              end,
            submitted_at_ethereum_height: index,
            formed_at_ethereum_height: index
          })

          {nonce + 1, blknum + 1000}
        end)

      parent = self()
      # this would be our vault
      integration_point = fn hash, nonce, gas ->
        Kernel.send(parent, {hash, nonce, gas})
        {:ok, "0x254ea979ba78f6adec707a97bc2dab8612c52b9047ffd47c81c2575e2373b699"}
      end

      ref = make_ref()

      gas_integration = fn ->
        Kernel.send(parent, ref)
        1
      end

      # at this height, I'm looking at what was submitted and what wasn't
      # I notice  that blocks with blknum from 1000 to 7000 were mined but above that it needs a resubmission
      my_current_eth_height = 6
      mined_child_block = 6000

      {:ok, %{get_all: blocks}} =
        Block.get_all_and_submit(my_current_eth_height, mined_child_block, integration_point, gas_integration)

      assert [] = blocks
      # assert that our integration point was called with these blocks
      [] = receive_all_blocks_nonces()
    end
  end

  describe "block formed and submited at the current height is not re-submitted" do
    test "even though mined blocks shows less! this would be a case where a newly formed block was submitted by some other childchain node and not the current one" do
      nonce = 1
      blknum = 2000
      my_current_eth_height = 6

      # just insert a block

      insert(:block, %{
        nonce: nonce,
        blknum: blknum,
        state: :submitted,
        submitted_at_ethereum_height: my_current_eth_height,
        formed_at_ethereum_height: my_current_eth_height
      })

      parent = self()
      # this would be our vault
      integration_point = fn hash, nonce, gas ->
        Kernel.send(parent, {hash, nonce, gas})
        {:ok, "0x254ea979ba78f6adec707a97bc2dab8612c52b9047ffd47c81c2575e2373b699"}
      end

      ref = make_ref()

      gas_integration = fn ->
        Kernel.send(parent, ref)
        1
      end

      # at this height, I'm looking at what was submitted and what wasn't
      # I notice  that blocks with blknum from 1000 to 7000 were mined but above that it needs a resubmission

      mined_child_block = 1000

      {:ok, %{get_all: blocks}} =
        Block.get_all_and_submit(my_current_eth_height, mined_child_block, integration_point, gas_integration)

      assert [] = blocks
      # assert that our integration point was called with these blocks
      [] = receive_all_blocks_nonces()
      :no_gas_reference = get_gas_ref()
    end
  end

  describe "a simulation of multiple childchains accesing block submission" do
    test "processes try to re-submit blocks" do
      nonce = 0
      blknum = 1000

      # just insert 10 blocks that were created over 10 eth blocks
      _ =
        Enum.reduce(1..10, {nonce, blknum}, fn index, {nonce, blknum} ->
          insert(:block, %{
            nonce: nonce,
            blknum: blknum,
            state: :confirmed,
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
        {:ok, "0x254ea979ba78f6adec707a97bc2dab8612c52b9047ffd47c81c2575e2373b699"}
      end

      ref = make_ref()

      gas_integration_point = fn ->
        Kernel.send(parent, ref)
        %{standard: 1}
      end

      # at this height, I'm looking at what was submitted and what wasn't
      # I notice  that blocks with blknum from 1000 to 7000 were mined but above that it needs a resubmission
      insert(:block, %{nonce: 10, blknum: 11_000, formed_at_ethereum_height: 11})

      my_current_eth_height = 11
      mined_child_block = 7000

      number_of_childchains = 10

      1..number_of_childchains
      |> Task.async_stream(
        fn _ ->
          Sandbox.allow(Engine.Repo, parent, self())
          Block.get_all_and_submit(my_current_eth_height, mined_child_block, integration_point, gas_integration_point)
        end,
        timeout: 5000,
        on_timeout: :kill_task,
        max_concurrency: System.schedulers_online()
      )
      |> Enum.map(fn {:ok, result} -> result end)

      # if submission was executed once, it was executed by one of the childchains
      # that WON the race, hence, we should receive nonces as messages only once
      ["7", "8", "9", "10"] = receive_all_blocks_nonces()
      ^ref = get_gas_ref()
    end
  end

  describe "finalize_forming_block/0" do
    test "changes state of a forming block" do
      %{id: id_forming} = insert_non_empty_block(Block.state_forming())
      block_forming = Repo.one(from(b in Block, where: b.id == ^id_forming))
      expected = %Block{block_forming | state: Block.state_finalizing()}
      assert :ok = Block.finalize_forming_block()
      actual = Repo.one(from(b in Block, where: b.id == ^id_forming))
      assert actual == expected
    end

    test "changes block state to finalizing only for a forming block" do
      _ = insert_non_empty_block(Block.state_forming())

      %{id: id_finalizing} = insert(:block, %{state: Block.state_finalizing()})
      block_finalizing = Repo.one(from(b in Block, where: b.id == ^id_finalizing))

      %{id: id_pending} = insert(:block, %{state: Block.state_pending_submission()})
      block_pending = Repo.one(from(b in Block, where: b.id == ^id_pending))

      %{id: id_submitted} = insert(:block, %{state: Block.state_submitted()})
      block_submitted = Repo.one(from(b in Block, where: b.id == ^id_submitted))

      %{id: id_confirmed} = insert(:block, %{state: Block.state_confirmed()})
      block_confirmed = Repo.one(from(b in Block, where: b.id == ^id_confirmed))

      assert :ok = Block.finalize_forming_block()

      assert Repo.one(from(b in Block, where: b.id == ^id_finalizing)) == block_finalizing
      assert Repo.one(from(b in Block, where: b.id == ^id_pending)) == block_pending
      assert Repo.one(from(b in Block, where: b.id == ^id_submitted)) == block_submitted
      assert Repo.one(from(b in Block, where: b.id == ^id_confirmed)) == block_confirmed
    end

    test "does not update forming block if it's empty" do
      %{id: id} = insert(:block, %{state: Block.state_forming()})
      block_before_call = Repo.one(from(b in Block, where: b.id == ^id))
      assert :ok == Block.finalize_forming_block()
      block_after_call = Repo.one(from(b in Block, where: b.id == ^id))
      assert block_after_call == block_before_call
    end

    test "does not fail when there is no forming block" do
      assert :ok == Block.finalize_forming_block()
    end
  end

  describe "prepare_for_submission/0" do
    setup do
      block = insert(:block, %{state: Block.state_finalizing()})
      {:ok, %{block: block}}
    end

    test "generates the block hash, changes block state to pending submission and sets formed ethereum height", %{
      block: finalizing_block
    } do
      tx = insert(:payment_v1_transaction, %{block: finalizing_block})
      hash = Merkle.root_hash([Transaction.encode_unsigned(tx)])

      eth_height = 10
      assert {:ok, %{blocks_for_submission: [block]}} = Block.prepare_for_submission(eth_height)
      assert block.hash == hash
      assert block.state == Block.state_pending_submission()
      assert block.formed_at_ethereum_height == eth_height
    end

    test "correctly generates block hash for empty txs list" do
      assert {:ok, %{blocks_for_submission: [block]}} = Block.prepare_for_submission(@eth_height)

      assert block.hash ==
               <<246, 9, 190, 253, 254, 144, 102, 254, 20, 231, 67, 179, 98, 62, 174, 135, 143, 188, 70, 128, 5, 96,
                 136, 22, 131, 44, 157, 70, 15, 42, 149, 210>>
    end

    test "block hash is consistent with childchain v1", %{block: block} do
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

        _ = insert(:payment_v1_transaction, %{block: block, tx_index: index, tx_bytes: tx_bytes})
      end)

      assert {:ok, %{blocks_for_submission: [block_for_submission]}} = Block.prepare_for_submission(@eth_height)

      assert block_for_submission.hash ==
               <<189, 245, 69, 5, 94, 45, 148, 210, 5, 89, 98, 245, 201, 111, 222, 48, 61, 114, 145, 55, 122, 84, 196,
                 156, 254, 80, 85, 184, 3, 205, 163, 233>>
    end

    @tag timeout: :infinity
    @tag :integration
    test "correctly calculates hash for a lot of transactions", %{block: block} do
      alice_priv_key =
        "0x" <>
          Base.encode16(
            <<54, 43, 207, 67, 140, 160, 190, 135, 18, 162, 70, 120, 36, 245, 106, 165, 5, 101, 183, 55, 11, 117, 126,
              135, 49, 50, 12, 228, 173, 219, 183, 175>>,
            case: :lower
          )

      bob_address = <<207, 194, 79, 222, 88, 128, 171, 217, 153, 41, 195, 239, 138, 178, 227, 16, 72, 173, 118, 35>>

      _ =
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

          _ = insert(:payment_v1_transaction, %{block: block, tx_index: index, tx_bytes: tx_bytes})
        end)

      assert {:ok, %{blocks_for_submission: [block_for_submission]}} = Block.prepare_for_submission(@eth_height)

      assert block_for_submission.hash ==
               <<12, 40, 202, 7, 16, 175, 119, 138, 7, 95, 8, 3, 148, 93, 162, 168, 136, 226, 196, 236, 83, 62, 220, 75,
                 59, 52, 6, 18, 249, 52, 124, 228>>
    end

    test "affects only blocks in finalizing state" do
      block_finalizing1 = insert_non_empty_block(Block.state_finalizing())
      block_finalizing2 = insert_non_empty_block(Block.state_finalizing())
      block_forming = insert_non_empty_block(Block.state_forming())
      block_pending_submission = insert_non_empty_block(Block.state_pending_submission())
      block_submitted = insert_non_empty_block(Block.state_submitted())
      block_confirmed = insert_non_empty_block(Block.state_confirmed())

      {:ok, _} = Block.prepare_for_submission(@eth_height)

      assert block_forming == Repo.get!(Block, block_forming.id)
      assert block_pending_submission == Repo.get!(Block, block_pending_submission.id)
      assert block_submitted == Repo.get!(Block, block_submitted.id)
      assert block_confirmed == Repo.get!(Block, block_confirmed.id)

      updated_block_finalizing1 = Repo.get!(Block, block_finalizing1.id)
      assert Block.state_pending_submission() == updated_block_finalizing1.state

      updated_block_finalizing2 = Repo.get!(Block, block_finalizing2.id)
      assert Block.state_pending_submission() == updated_block_finalizing2.state
    end

    test "attaches fee transactions to blocks" do
      block1 = insert_non_empty_block(Block.state_finalizing())

      tx1 =
        insert(:payment_v1_transaction, %{
          block: block1,
          tx_index: 1,
          inputs: [%{amount: 2, token: @eth}],
          outputs: [%{amount: 1, token: @eth}]
        })

      _ = insert(:transaction_fee, %{transaction: tx1, currency: @eth, amount: 1})

      tx2 =
        insert(:payment_v1_transaction, %{
          block: block1,
          tx_index: 2,
          inputs: [%{amount: 2, token: @other_token}],
          outputs: [%{amount: 1, token: @other_token}]
        })

      _ = insert(:transaction_fee, %{transaction: tx2, currency: @other_token, amount: 1})

      block2 = insert_non_empty_block(Block.state_finalizing())

      tx3 =
        insert(:payment_v1_transaction, %{
          block: block2,
          tx_index: 1,
          inputs: [%{amount: 10, token: @other_token}],
          outputs: [%{amount: 1, token: @other_token}]
        })

      _ = insert(:transaction_fee, %{transaction: tx3, currency: @other_token, amount: 9})

      {:ok, _} = Block.prepare_for_submission(@eth_height)

      [fee_transaction1_block1, fee_transaction2_block1] = fee_transactions_for_block(block1)

      assert expect_output_in_transaction(fee_transaction1_block1, %{
               amount: 2,
               output_guard: Configuration.fee_claimer_address(),
               token: @eth
             })

      assert expect_output_in_transaction(fee_transaction2_block1, %{
               amount: 1,
               output_guard: Configuration.fee_claimer_address(),
               token: @other_token
             })

      [fee_transaction1_block2, fee_transaction2_block2] = fee_transactions_for_block(block2)

      assert expect_output_in_transaction(fee_transaction1_block2, %{
               amount: 1,
               output_guard: Configuration.fee_claimer_address(),
               token: @eth
             })

      assert expect_output_in_transaction(fee_transaction2_block2, %{
               amount: 9,
               output_guard: Configuration.fee_claimer_address(),
               token: @other_token
             })
    end

    test "payment transaction indicies and fee transaction indicies form a continous range of natural numbers" do
      block = insert_non_empty_block(Block.state_finalizing())

      tx =
        insert(:payment_v1_transaction, %{
          block: block,
          tx_index: 1,
          inputs: [%{amount: 10, token: @other_token}],
          outputs: [%{amount: 1, token: @other_token}]
        })

      _ = insert(:transaction_fee, %{transaction: tx, currency: @other_token, amount: 9})

      {:ok, _} = Block.prepare_for_submission(@eth_height)

      [fee_transaction1, fee_transaction2] =
        block.id
        |> TransactionQuery.fetch_transactions_from_block()
        |> Repo.all()
        |> Enum.filter(fn %Transaction{tx_type: tx_type} -> tx_type == ExPlasma.fee() end)

      assert 2 == fee_transaction1.tx_index
      assert 3 == fee_transaction2.tx_index
    end

    test "handles conflicts for concurrent calls" do
      :ok = Enum.each(1..50, fn _ -> insert_non_empty_block(Block.state_finalizing()) end)

      no_conflicts =
        1..50
        |> Enum.map(fn _ -> Task.async(fn -> Block.prepare_for_submission(@eth_height) end) end)
        |> Enum.map(fn task -> Task.await(task) end)
        |> Enum.all?(fn
          {:ok, _} -> true
          _ -> false
        end)

      assert no_conflicts
    end
  end

  defp fee_transactions_for_block(block) do
    fee_tx_type = ExPlasma.fee()
    Repo.all(from(t in Transaction, where: t.block_id == ^block.id and t.tx_type == ^fee_tx_type, order_by: t.tx_index))
  end

  defp expect_output_in_transaction(transaction, expected_output) do
    {:ok, plasma_fee_transaction} = ExPlasma.decode(transaction.tx_bytes)
    assert %{outputs: [fee_output1]} = plasma_fee_transaction
    assert %{output_data: ^expected_output, output_type: 2} = fee_output1

    true
  end

  defp insert_non_empty_block(block_state) do
    block = insert(:block, %{state: block_state})

    transaction =
      insert(:payment_v1_transaction, %{
        block: block,
        tx_index: 0,
        inputs: [%{amount: 2, token: @eth}],
        outputs: [%{amount: 1, token: @eth}]
      })

    _ = insert(:transaction_fee, %{transaction: transaction, currency: @eth, amount: 1})

    Repo.get(Block, block.id)
  end

  defp receive_all_blocks_nonces() do
    receive_all_blocks_nonces([])
  end

  defp receive_all_blocks_nonces(acc) do
    receive do
      {_hash, nonce, _gas} -> receive_all_blocks_nonces([nonce | acc])
    after
      50 ->
        # list appending adds at the tail so we need to reverse it once done
        Enum.reverse(acc)
    end
  end

  defp get_gas_ref() do
    receive do
      ref when is_reference(ref) -> ref
    after
      50 ->
        # list appending adds at the tail so we need to reverse it once done
        :no_gas_reference
    end
  end

  defp vault_response_mock() do
    {:ok,
     %HTTPoison.Response{
       body:
         "{\"request_id\":\"210fed77-15f8-7b11-b8a3-9628b97cd716\",\"lease_id\":\"\",\"renewable\":false,\"lease_duration\":0,\"data\":{\"contract\":\"0x23764956B3FC5f3d86586b1422Ca528559A07161\",\"from\":\"0x7F76d4380Fe855C7E215aA0ca9DeDEAeD0680359\",\"gas_limit\":72803,\"gas_price\":31000000000,\"nonce\":0,\"signed_transaction\":\"0xf88980850737be760083011c639423764956b3fc5f3d86586b1422ca528559a0716180a4baa47694463f9b9cfbb3efd3284b8f72e0786de08e7d2aab26745335ab8495d2cfa0635e1ca093aff875b1e328865972256868d87dd3611a40411351346b510320cfb5a5cd4aa07b7b8ef7897ffc0d203f3626ec271a4aaa26f656de4da7bf54c7584977b1c7c5\",\"transaction_hash\":\"0x2cc6777a4ec6ab4ceeec23aa5ec355bbab84fc5f1208d87f3ca893f17e3e7fe2\"},\"wrap_info\":null,\"warnings\":null,\"auth\":null}\n",
       headers: [
         {"Cache-Control", "no-store"},
         {"Content-Type", "application/json"},
         {"Date", "Wed, 09 Dec 2020 17:53:03 GMT"},
         {"Content-Length", "711"}
       ],
       request: %HTTPoison.Request{
         body:
           "{\"block_root\":\"Rj+bnPuz79MoS49y4Hht4I59KqsmdFM1q4SV0s+gY14=\",\"contract\":\"0x23764956B3FC5f3d86586b1422Ca528559A07161\",\"gas_price\":\"31000000000\",\"nonce\":\"0\"}",
         headers: [
           {"X-Vault-Request", true},
           {"X-Vault-Token", "s.tLPnLvpaRtYYsLAxPpCT6lHn"}
         ],
         method: :put,
         options: [hackney: [:insecure]],
         params: %{},
         url:
           "https://127.0.0.1:8200/v1/immutability-eth-plugin/wallets/plasma-deployer/accounts/0x7F76d4380Fe855C7E215aA0ca9DeDEAeD0680359/plasma/submitBlock"
       },
       request_url:
         "https://127.0.0.1:8200/v1/immutability-eth-plugin/wallets/plasma-deployer/accounts/0x7F76d4380Fe855C7E215aA0ca9DeDEAeD0680359/plasma/submitBlock",
       status_code: 200
     }}
  end
end
