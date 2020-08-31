defmodule Engine.DB.PlasmaBlock do
  @moduledoc """
  Ecto schema for you know what.
  """

  use Ecto.Schema
  use Spandex.Decorators

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2, limit: 2]

  alias Ecto.Multi
  alias Engine.DB.Transaction
  alias Engine.Repo
  alias ExPlasma.Merkle

  require Logger

  @optional_fields [:hash, :tx_hash, :formed_at_ethereum_height, :submitted_at_ethereum_height, :gas, :attempts_counter]
  @required_fields [:nonce, :blknum]

  @type t() :: %{
          hash: binary(),
          nonce: pos_integer(),
          blknum: pos_integer() | nil,
          tx_hash: binary() | nil,
          formed_at_ethereum_height: pos_integer() | nil,
          id: pos_integer(),
          submitted_at_ethereum_height: pos_integer() | nil,
          gas: pos_integer() | nil,
          attempts_counter: non_neg_integer(),
          transactions: [Transaction.t()],
          updated_at: DateTime.t(),
          inserted_at: DateTime.t()
        }

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

    has_many(:transactions, Transaction,
      foreign_key: :block_id,
      references: :id
    )

    timestamps(type: :utc_datetime)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
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
    |> Multi.run("new-block", &insert_block/2)
    |> Multi.run("form-block", &attach_block_to_transactions/2)
    |> Multi.run("hash-block", &generate_block_hash/2)
    |> Repo.transaction()
  end

  @doc """
  Get a block by its hash, because of https://github.com/omgnetwork/plasma-contracts/issues/359
  block hash are not necessarly unique, until this is fixed, we limit the result to the first block we find.
  If deposit blocks are stored in a different table than plasma blocks, we can have a unique hash enforced at
  the db level and thus we can drop the limit(1) here.
  """
  @spec get_by_hash(binary(), atom() | list(atom())) :: {:ok, t()} | {:error, nil}
  def get_by_hash(hash, preloads) do
    hash
    |> query_by_hash()
    |> limit(1)
    |> Repo.one()
    |> Repo.preload(preloads)
    |> case do
      nil -> {:error, nil}
      block -> {:ok, block}
    end
  end

  @doc """
  Query the most recent block by it's hash, which is not necessarily unique.
  """
  def query_by_hash(hash) do
    from(b in __MODULE__, where: b.hash == ^hash, order_by: b.inserted_at)
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
        |> change(
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

  defp insert_block(repo, _params) do
    max_db_nonce = Repo.one(from(block in __MODULE__, select: max(block.nonce)))

    nonce =
      case max_db_nonce do
        nil -> 1
        found_nonce -> found_nonce + 1
      end

    blknum = nonce * 1_000

    params = %{nonce: nonce, blknum: blknum}

    %__MODULE__{}
    |> changeset(params)
    |> repo.insert()
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
    changeset = change(block, hash: hash)
    repo.update(changeset)
  end
end
