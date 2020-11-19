defmodule Engine.BlockForming.PrepareForSubmissionTest do
  use Engine.DB.DataCase, async: false

  alias Engine.BlockForming.PrepareForSubmission
  alias Engine.DB.Block

  @interval_ms 10
  @eth <<0::160>>

  defmodule EthereumHeightModuleMock do
    def get(), do: {:ok, 1}
  end

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

  test "periodically prepares blocks for submission" do
    config = [
      prepare_block_for_submission_interval_ms: @interval_ms,
      ethereum_height_module: EthereumHeightModuleMock
    ]

    block1 = insert_non_empty_block(Block.state_finalizing())
    block2 = insert_non_empty_block(Block.state_finalizing())
    block3 = insert_non_empty_block(Block.state_confirmed())
    block4 = insert_non_empty_block(Block.state_forming())

    {:ok, _} = PrepareForSubmission.start_link(config)

    Process.sleep(3 * @interval_ms)

    block_pending_submission1 = Repo.get(Block, block1.id)
    assert Block.state_pending_submission() == block_pending_submission1.state

    block_pending_submission2 = Repo.get(Block, block2.id)
    assert Block.state_pending_submission() == block_pending_submission2.state

    block_confirmed = Repo.get(Block, block3.id)
    assert block3.state == block_confirmed.state

    block_forming = Repo.get(Block, block4.id)
    assert block4.state == block_forming.state

    _ =
      block_forming
      |> Ecto.Changeset.change(%{state: Block.state_finalizing()})
      |> Repo.update()

    Process.sleep(3 * @interval_ms)

    prepared_block = Repo.get(Block, block_forming.id)
    assert Block.state_pending_submission() == prepared_block.state
  end

  test "backs off on alert" do
    config = [
      prepare_block_for_submission_interval_ms: @interval_ms,
      ethereum_height_module: EthereumHeightModuleMock
    ]

    {:ok, worker} = PrepareForSubmission.start_link(config)
    GenServer.cast(worker, {:set_alarm, :db_connection_lost})
    assert %{connection_alarm_raised: true} = :sys.get_state(worker)

    block = insert_non_empty_block(Block.state_finalizing())
    Process.sleep(3 * @interval_ms)

    block_finalizing = Repo.get(Block, block.id)
    assert Block.state_finalizing() == block_finalizing.state

    GenServer.cast(worker, {:clear_alarm, :db_connection_lost})
    assert %{connection_alarm_raised: false} = :sys.get_state(worker)
    Process.sleep(3 * @interval_ms)

    updated_block = Repo.get(Block, block.id)
    assert Block.state_pending_submission() == updated_block.state
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
end
