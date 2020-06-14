defmodule Engine.DB.PlasmaBlockTest do
  use Engine.DB.DataCase, async: true
  import Ecto.Query, only: [from: 2]

  alias Ecto.Adapters.SQL.Sandbox
  alias Engine.DB.PlasmaBlock

  test "integration point is not called when there are no blocks to submit" do
    parent = self()

    integration = fn hash, nonce, gas ->
      Kernel.send(parent, {hash, nonce, gas})
    end

    assert PlasmaBlock.get_all_and_submit(1000, 1000, integration) == {:ok, %{compute_gas_and_submit: [], get_all: []}}
    refute_receive _
  end

  describe "this would be a normal case where a node sees some plasma blocks are not mined and adjust gas for those and re-submits them" do
    test "10 block in DB, 7 in ethereum, submit 3 in nonce order" do
      nonce = 1
      blknum = 1000

      # just insert 10 blocks that were created over 10 eth blocks
      _ =
        Enum.reduce(1..10, {nonce, blknum}, fn index, {nonce, blknum} ->
          insert(:plasma_block, %{
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

      {:ok, %{get_all: blocks}} =
        PlasmaBlock.get_all_and_submit(my_current_eth_height, mined_child_block, integration_point)

      assert [%{nonce: 8}, %{nonce: 9}, %{nonce: 10}] = blocks
      # assert that our integration point was called with these blocks
      [8, 9, 10] = receive_all_blocks()

      sql =
        from(plasma_block in PlasmaBlock,
          where: plasma_block.nonce == 8 or plasma_block.nonce == 9 or plasma_block.nonce == 10
        )

      sql
      |> Engine.Repo.all()
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
          insert(:plasma_block, %{
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
      insert(:plasma_block, %{nonce: 11, blknum: 11_000, formed_at_ethereum_height: 11})

      my_current_eth_height = 11
      mined_child_block = 7000

      {:ok, %{get_all: blocks}} =
        PlasmaBlock.get_all_and_submit(my_current_eth_height, mined_child_block, integration_point)

      assert [%{nonce: 8}, %{nonce: 9}, %{nonce: 10}, %{nonce: 11}] = blocks
      # assert that our integration point was called with these blocks
      [8, 9, 10, 11] = receive_all_blocks()

      sql =
        from(plasma_block in PlasmaBlock,
          where:
            plasma_block.nonce == 8 or plasma_block.nonce == 9 or plasma_block.nonce == 10 or plasma_block.nonce == 11
        )

      sql
      |> Engine.Repo.all()
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
          insert(:plasma_block, %{
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

      {:ok, %{get_all: blocks}} =
        PlasmaBlock.get_all_and_submit(my_current_eth_height, mined_child_block, integration_point)

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

      insert(:plasma_block, %{
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

      {:ok, %{get_all: blocks}} =
        PlasmaBlock.get_all_and_submit(my_current_eth_height, mined_child_block, integration_point)

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
          insert(:plasma_block, %{
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
      insert(:plasma_block, %{nonce: 11, blknum: 11_000, formed_at_ethereum_height: 11})

      my_current_eth_height = 11
      mined_child_block = 7000

      number_of_childchains = 10

      1..number_of_childchains
      |> Task.async_stream(
        fn _ ->
          Sandbox.allow(Engine.Repo, parent, self())
          PlasmaBlock.get_all_and_submit(my_current_eth_height, mined_child_block, integration_point)
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
