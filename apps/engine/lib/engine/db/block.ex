defmodule Engine.DB.Block do
  @moduledoc """
  Represent a block of transactions that will be submitted to the contracts.

  This contains information for all blocks, which are:

  * Deposit blocks. This is picked up from events emitted from the rootchain / contracts.
  * Plasma blocks. This is blocks that the childchain will submit to the contracts.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Engine.DB.Transaction

  @type transaction_response() ::
          {:ok, any()}
          | {:error, any()}
          | {:error, Ecto.Multi.name(), any(), %{required(Ecto.Multi.name()) => any()}}

  schema "blocks" do
    field(:hash, :binary)
    field(:number, :integer)
    field(:state, :string)

    field(:nonce, :integer)
    field(:gas, :integer)
    field(:height, :integer)

    has_many(:transactions, Transaction)

    embeds_many :submissions, Submission do
      field(:gas, :integer)
      field(:height, :integer)
      timestamps(type: :utc_datetime, updated_at: false)
    end

    timestamps(type: :utc_datetime)
  end

  @spec changeset(struct(), map()) :: Ecto.Changeset.t()
  def changeset(schema, params) do
    schema
    |> cast(params, [:hash, :number, :state])
    |> cast_assoc(:transactions)
    |> unique_constraint(:number)
  end

  @doc """
  Builds a changeset with a new submission.
  """
  @spec submit_attempt(struct(), map()) :: Ecto.Changeset.t()
  def submit_attempt(schema, params) do
    submissions = Enum.map(schema.submissions, &Map.from_struct/1)

    schema
    |> changeset(%{submissions: submissions ++ [params]})
    |> cast_embed(:submissions, with: &submission_changeset/2)
  end

  @doc """
  Forms a pending block record based on the existing pending transactions. This
  attaches free transactions into a new block, awaiting for submission to the contract
  later on.
  """
  @spec form() :: transaction_response()
  def form() do
    Ecto.Multi.new()
    |> Ecto.Multi.insert("new-block", %__MODULE__{})
    |> Ecto.Multi.run("form-block", &attach_block_to_transactions/2)
    |> Ecto.Multi.run("hash-block", &generate_block_hash/2)
    |> Engine.Repo.transaction()
  end

  defp attach_block_to_transactions(repo, %{"new-block" => block}) do
    updates = [block_id: block.id, updated_at: NaiveDateTime.utc_now()]
    {total, _} = repo.update_all(Transaction.pending(), set: updates)

    {:ok, total}
  end

  defp generate_block_hash(repo, %{"new-block" => block}) do
    txns = Engine.Repo.preload(block, :transactions).transactions
    hash = txns |> Enum.map(& &1.tx_bytes) |> ExPlasma.Encoding.merkle_root_hash()
    changeset = Ecto.Changeset.change(block, hash: hash)
    repo.update(changeset)
  end

  defp submission_changeset(schema, params) do
    cast(schema, params, [:gas, :height, :inserted_at])
  end
end
