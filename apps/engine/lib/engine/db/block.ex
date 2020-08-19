defmodule Engine.DB.Block do
  @moduledoc """
  Represent a block of transactions that will be submitted to the contracts.
  """

  use Ecto.Schema
  use Spandex.Decorators

  import Ecto.Changeset
  import Ecto.Query

  alias Ecto.Changeset
  alias Ecto.Multi
  alias Engine.DB.Transaction
  alias Engine.Repo
  alias ExPlasma.Merkle

  @type t() :: %{
          transactions: list(Transaction.t()),
          id: pos_integer(),
          state: String.t(),
          number: pos_integer(),
          hash: <<_::256>>,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "blocks" do
    field(:hash, :binary)
    field(:number, :integer)
    field(:state, :string)

    has_many(:transactions, Transaction)

    timestamps(type: :utc_datetime)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:hash, :number, :state])
    |> cast_assoc(:transactions)
    |> unique_constraint(:number)
  end

  @doc """
  Query the most recent block by it's hash, which is not necessarily unique.
  """
  def query_by_hash(hash) do
    from(b in __MODULE__, where: b.hash == ^hash, order_by: b.inserted_at)
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
