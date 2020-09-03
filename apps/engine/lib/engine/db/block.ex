defmodule Engine.DB.Block do
  @moduledoc """
  Ecto schema that represents "Plasma Blocks" that are being submitted from the Childchain to the contracts. This holds metadata information and a reference point to associated transactions that are formed into said Block.
  """

  use Ecto.Schema
  use Spandex.Decorators

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  alias Ecto.Multi
  alias Engine.DB.Transaction
  alias Engine.Repo
  alias ExPlasma.Merkle

  require Logger

  @block_number_multiplier 1_000

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

  @type transaction_result_t() ::
          {:ok, any()}
          | {:error, any()}
          | {:error, Ecto.Multi.name(), any(), %{required(Ecto.Multi.name()) => any()}}

  schema "blocks" do
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

  @spec get_all_and_submit(pos_integer(), pos_integer(), function()) :: transaction_result_t()
  def get_all_and_submit(new_height, mined_child_block, submit) do
    Multi.new()
    |> Multi.run(:get_all, fn repo, changeset ->
      get_all(repo, changeset, new_height, mined_child_block)
    end)
    |> Multi.run(:compute_gas_and_submit, fn repo, changeset ->
      compute_gas_and_submit(repo, changeset, new_height, mined_child_block, submit)
    end)
    |> Repo.transaction()
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
    |> Multi.run("form-block", &attach_transactions_to_block/2)
    |> Multi.run("hash-block", &generate_block_hash/2)
    |> Repo.transaction()
  end

  @doc """
  Get a block by its hash.
  """
  @spec get_by_hash(binary(), atom() | list(atom())) :: {:ok, t()} | {:error, nil}
  def get_by_hash(hash, preloads) do
    __MODULE__
    |> Repo.get_by(hash: hash)
    |> Repo.preload(preloads)
    |> case do
      nil -> {:error, nil}
      block -> {:ok, block}
    end
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
    nonce =
      query_max_nonce()
      |> Repo.one()
      |> case do
        nil -> 1
        found_nonce -> found_nonce + 1
      end

    blknum = nonce * @block_number_multiplier

    params = %{nonce: nonce, blknum: blknum}

    %__MODULE__{}
    |> changeset(params)
    |> repo.insert()
  end

  defp query_max_nonce(), do: from(block in __MODULE__, select: max(block.nonce))

  defp attach_transactions_to_block(repo, %{"new-block" => block}) do
    updates = [block_id: block.id, updated_at: NaiveDateTime.utc_now()]
    {total, _} = repo.update_all(Transaction.pending(), set: updates)

    {:ok, total}
  end

  defp generate_block_hash(repo, %{"new-block" => block}) do
    hash =
      block.id
      |> fetch_tx_bytes_in_block()
      |> Merkle.root_hash()

    changeset = change(block, hash: hash)
    repo.update(changeset)
  end

  defp fetch_tx_bytes_in_block(block_id) do
    query = from(transaction in Transaction, where: transaction.block_id == ^block_id)

    query
    |> Repo.all()
    |> Enum.map(fn tx ->
      Transaction.decode_tx_bytes(tx)
    end)
  end
end
