defmodule Engine.DB.Block do
  @moduledoc """
  Represent a block of transactions that will be submitted to the contracts.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Engine.DB.Transaction
  alias Engine.Repo

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
    |> generate_block_hash()
  end

  @doc """
  Forms a pending block record based on the existing pending transactions. This
  attaches free transactions into a new block, awaiting for submission to the contract
  later on.
  """
  def form() do
    Ecto.Multi.new()
    |> Ecto.Multi.insert("new-block", %__MODULE__{})
    |> Ecto.Multi.run("form-block", &attach_block_to_transactions/2)
    |> Ecto.Multi.run("hash-block", &attach_hash/2)
    |> Repo.transaction()
  end

  @doc """
  Grab the most recent block by it's hash, which is not necessarily unique.
  """
  def get_by_hash(hash) do
    query = from(b in __MODULE__, where: b.hash == ^hash, order_by: b.inserted_at, limit: 1)
    query |> Repo.all() |> hd()
  end

  defp attach_block_to_transactions(repo, %{"new-block" => block}) do
    updates = [block_id: block.id, updated_at: NaiveDateTime.utc_now()]
    {total, _} = repo.update_all(Transaction.pending(), set: updates)

    {:ok, total}
  end

  defp attach_hash(repo, %{"new-block" => block}) do
    block
    |> Repo.preload(:transactions)
    |> changeset(%{})
    |> repo.update()
  end

  defp generate_block_hash(changeset) do
    hash =
      changeset
      |> get_field(:transactions)
      |> Enum.map(& &1.tx_bytes)
      |> ExPlasma.Encoding.merkle_root_hash()

    put_change(changeset, :hash, hash)
  end
end
