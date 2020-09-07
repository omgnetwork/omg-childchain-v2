defmodule Engine.DB.PlasmaBlock do
  @moduledoc """
  Ecto schema for you know what.
  """

  use Ecto.Schema
  # import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  require Logger

  @timestamps_opts [inserted_at: :node_inserted_at, updated_at: :node_updated_at]

  schema "plasma_blocks" do
    # Extracted from `output_id`
    field(:hash, :binary)
    field(:nonce, :integer)
    field(:blknum, :integer)
    field(:tx_hash, :binary)
    field(:formed_at_ethereum_height, :integer)
    field(:submitted_at_ethereum_height, :integer)
    field(:gas, :integer)
    field(:attempts_counter, :integer)

    field(:inserted_at, :utc_datetime)
    field(:updated_at, :utc_datetime)

    timestamps()
  end

  @spec get_all_and_submit(pos_integer(), pos_integer(), function()) ::
          {:ok, any()}
          | {:error, any()}
          | {:error, Ecto.Multi.name(), any(), %{required(Ecto.Multi.name()) => any()}}
  def get_all_and_submit(new_height, mined_child_block, submit) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:get_all, fn repo, changeset ->
      get_all(repo, changeset, new_height, mined_child_block)
    end)
    |> Ecto.Multi.run(:compute_gas_and_submit, fn repo, changeset ->
      compute_gas_and_submit(repo, changeset, new_height, mined_child_block, submit)
    end)
    |> Engine.Repo.transaction()
  end

  defp get_all(repo, _changeset, new_height, mined_child_block) do
    query =
      from(p in __MODULE__,
        where:
          (p.submitted_at_ethereum_height < ^new_height or is_nil(p.submitted_at_ethereum_height)) and
            p.blknum > ^mined_child_block,
        order_by: [asc: :nonce]
      )

    {:ok, repo.all(query)}
  end

  defp compute_gas_and_submit(repo, %{get_all: plasma_blocks}, new_height, mined_child_block, submit) do
    :ok = process_submission(repo, plasma_blocks, new_height, mined_child_block, submit)
    {:ok, []}
  end

  defp process_submission(_repo, [], _new_height, _mined_child_block, _submit) do
    :ok
  end

  defp process_submission(repo, [plasma_block | plasma_blocks], new_height, mined_child_block, submit) do
    # get appropriate gas here
    gas = plasma_block.gas + 1

    case submit.(plasma_block.hash, plasma_block.nonce, gas) do
      :ok ->
        plasma_block
        |> Ecto.Changeset.change(
          gas: gas,
          attempts_counter: plasma_block.attempts_counter + 1,
          submitted_at_ethereum_height: new_height
        )
        |> repo.update!([])

        process_submission(repo, plasma_blocks, new_height, mined_child_block, submit)

      error ->
        # we encountered an error with one of the block submissions
        # we'll stop here and continue later
        _ = Logger.error("Block submission stopped at block with nonce #{plasma_block.nonce}. Error: #{inspect(error)}")
        process_submission(repo, [], new_height, mined_child_block, submit)
    end
  end
end
