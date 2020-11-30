defmodule Engine.BlockFormation.PrepareForSubmissionTest do
  use Engine.DB.DataCase, async: false

  alias Engine.BlockFormation.PrepareForSubmission
  alias Engine.DB.Block

  @sleep_time_ms 1_000
  @eth <<0::160>>

  setup do
    case Application.start(:sasl) do
      {:error, {:already_started, :sasl}} ->
        :ok = Application.stop(:sasl)
        :ok = Application.start(:sasl)

      :ok ->
        :ok
    end

    on_exit(fn ->
      Application.stop(:sasl)
    end)

    :ok
  end

  test "finalizes forming block and prepares finalizing blocks for submission" do
    config = [
      block_submit_every_nth: 1
    ]

    block1 = insert_non_empty_block(Block.state_forming())
    block2 = insert_non_empty_block(Block.state_finalizing())
    block3 = insert_non_empty_block(Block.state_confirmed())

    _ = PrepareForSubmission.start_link(config)

    eth_height = 10
    _ = ethereum_height_tick(eth_height)
    _ = Process.sleep(@sleep_time_ms)

    state_pending_submission = Block.state_pending_submission()
    assert %Block{state: ^state_pending_submission, formed_at_ethereum_height: ^eth_height} = Repo.get(Block, block1.id)
    assert %Block{state: ^state_pending_submission, formed_at_ethereum_height: ^eth_height} = Repo.get(Block, block2.id)

    state_confirmed = Block.state_confirmed()

    assert %Block{state: ^state_confirmed} = Repo.get(Block, block3.id)
  end

  test "does not finalize forming block if ethereum height didn't change enough" do
    config = [
      block_submit_every_nth: 3
    ]

    _ = PrepareForSubmission.start_link(config)

    block1 = insert_non_empty_block(Block.state_forming())
    _ = ethereum_height_tick(2)
    _ = Process.sleep(@sleep_time_ms)
    block_forming = Repo.get(Block, block1.id)
    assert Block.state_forming() == block_forming.state
  end

  test "backs off on alert" do
    config = [
      block_submit_every_nth: 1
    ]

    {:ok, pid} = PrepareForSubmission.start_link(config)
    :ok = GenServer.cast(pid, {:set_alarm, :db_connection_lost})
    assert %{connection_alarm_raised: true} = :sys.get_state(pid)

    state_forming = Block.state_forming()
    state_finalizing = Block.state_finalizing()
    block1 = insert_non_empty_block(state_forming)
    block2 = insert_non_empty_block(state_finalizing)
    _ = ethereum_height_tick(2)
    Process.sleep(@sleep_time_ms)

    assert %Block{state: ^state_forming} = Repo.get(Block, block1.id)
    assert %Block{state: ^state_finalizing} = Repo.get(Block, block2.id)

    :ok = GenServer.cast(pid, {:clear_alarm, :db_connection_lost})
    _ = ethereum_height_tick(3)

    Process.sleep(@sleep_time_ms)
    assert %{connection_alarm_raised: false} = :sys.get_state(pid)

    state_pending = Block.state_pending_submission()
    assert %Block{state: ^state_pending} = Repo.get(Block, block1.id)
    assert %Block{state: ^state_pending} = Repo.get(Block, block2.id)
  end

  defp insert_non_empty_block(block_state) do
    block = insert(:block, %{state: block_state})

    _ =
      insert(:payment_v1_transaction, %{
        block: block,
        tx_index: 0,
        inputs: [%{amount: 2, token: @eth}],
        outputs: [%{amount: 1, token: @eth}]
      })

    Repo.get(Block, block.id)
  end

  defp ethereum_height_tick(height) do
    event = Bus.Event.new({:root_chain, "ethereum_new_height"}, :ethereum_new_height, height)
    Bus.local_broadcast(event)
  end
end
