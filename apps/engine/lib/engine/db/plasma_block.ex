defmodule Engine.DB.PlasmaBlock do
  @moduledoc """
  Ecto schema for you know what.
  """

  use Ecto.Schema
  use Spandex.Decorators
  import Ecto.Query, only: [from: 2]

  require Logger

  alias Ecto.Changeset
  alias Ecto.Multi
  alias Engine.DB.Transaction
  alias Engine.Repo
  alias ExPlasma.Merkle

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

    timestamps(type: :utc_datetime)
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

  @doc """
  Forms a pending block record based on the existing pending transactions. This
  attaches free transactions into a new block, awaiting for submission to the contract
  later on.
  """
  @decorate trace(service: :ecto, type: :backend)
  def form() do
    Multi.new()
    |> Multi.insert("new-block", %__MODULE__{})
    |> Multi.run("form-block", &attach_block_to_transactions/2)
    |> Multi.run("hash-block", &generate_block_hash/2)
    |> Repo.transaction()
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

  defp attach_block_to_transactions(repo, %{"new-block" => block}) do
    updates = [block_id: block.id, updated_at: NaiveDateTime.utc_now()]
    {total, _} = repo.update_all(Transaction.pending(), set: updates)

    {:ok, total}
  end

  defp generate_block_hash(repo, %{"new-block" => block}) do
    transactions_query =
      from(transaction in Transaction, where: transaction.block_id == ^block.id, select: transaction.tx_bytes)

    hash = transactions_query |> Repo.all() |> Merkle.root_hash()
    changeset = Changeset.change(block, hash: hash)
    repo.update(changeset)
  end
end
