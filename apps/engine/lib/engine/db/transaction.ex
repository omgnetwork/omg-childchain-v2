defmodule Engine.DB.Transaction do
  @moduledoc """
  The Transaction record. This is one of the main entry points for the system, specifically accepting
  transactions into the Childchain as `tx_bytes`. This expands those bytes into:

  * `tx_bytes` - A binary of a transaction encoded by RLP.
  * `inputs`  - The outputs that the transaction is acting on, and changes state e.g marked as "spent"
  * `outputs` - The newly created outputs

  More information is contained in the `tx_bytes`. However, to keep the Childchain _lean_, we extract
  data onto the record as needed.
  """

  use Ecto.Schema
  import Ecto.Changeset, only: [cast: 3, cast_assoc: 2, validate_required: 2]
  import Ecto.Query, only: [from: 2]

  alias Engine.DB.Block
  alias Engine.DB.Output
  alias Engine.DB.Transaction.Validator
  alias Engine.Repo

  @type tx_bytes :: binary

  @type t() :: %{
          block: Block.t(),
          block_id: pos_integer(),
          id: pos_integer(),
          inputs: list(Output.t()),
          inserted_at: DateTime.t(),
          kind: :deposit | :transfer,
          outputs: list(Output.t()),
          signed_tx: ExPlasma.Transaction.Signed.t() | nil,
          tx_bytes: binary(),
          tx_hash: <<_::256>>,
          tx_type: pos_integer(),
          updated_at: DateTime.t(),
          witnesses: DateTime.t()
        }

  @deposit :deposit
  @transfer :transfer

  def kind_transfer(), do: @transfer
  def kind_deposit(), do: @deposit

  schema "transactions" do
    field(:tx_bytes, :binary)
    field(:tx_hash, :binary)
    field(:tx_type, :integer)
    field(:kind, Ecto.Atom)

    # Virtual fields used for convenience and validation
    # Avoid decoding/parsing signatures mutiple times along validation process
    field(:witnesses, {:array, :string}, virtual: true)
    # Avoid calling decode(tx_bytes) multiple times along the validation process
    field(:signed_tx, :map, virtual: true)

    belongs_to(:block, Block)
    has_many(:inputs, Output, foreign_key: :spending_transaction_id)
    has_many(:outputs, Output, foreign_key: :creating_transaction_id)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Query all transactions that have not been formed into a block.
  """
  def pending(), do: from(t in __MODULE__, where: is_nil(t.block_id))

  @doc """
  Find transactions by the tx_hash.
  """
  def find_by_tx_hash(tx_hash), do: from(t in __MODULE__, where: t.tx_hash == ^tx_hash)

  @doc """
  The main action of the system. Takes tx_bytes and forms the appropriate
  associations for the transaction and outputs and runs the changeset.
  """
  @spec decode(tx_bytes, atom()) :: {:ok, Ecto.Changeset.t()} | {:error, atom()}
  def decode(tx_bytes, kind) do
    with {:ok, decoded} <- ExPlasma.decode(tx_bytes),
         {:ok, recovered} <- ExPlasma.Transaction.with_witnesses(decoded) do
      params =
        recovered
        |> recovered_to_map()
        # TODO: Handle fees, load from DB? Buffer period, format?
        |> Map.put(:fees, :no_fees_required)
        |> Map.put(:kind, kind)
        |> Map.put(:tx_bytes, tx_bytes)

      {:ok, changeset(%__MODULE__{}, params)}
    end
  end

  def changeset(struct, params) do
    struct
    |> Repo.preload(:inputs)
    |> Repo.preload(:outputs)
    |> cast(params, [:witnesses, :tx_hash, :signed_tx, :tx_bytes, :tx_type, :kind])
    |> validate_required([:witnesses, :tx_hash, :signed_tx, :tx_bytes, :tx_type, :kind])
    |> cast_assoc(:inputs)
    |> cast_assoc(:outputs)
    |> Validator.validate_protocol()
    |> Validator.validate_inputs()
    |> Validator.validate_statefully(params)
  end

  def insert(changeset), do: Repo.insert(changeset)

  defp recovered_to_map(transaction) do
    inputs = Enum.map(transaction.inputs, &Map.from_struct/1)
    outputs = Enum.map(transaction.outputs, &Map.from_struct/1)
    tx_hash = ExPlasma.hash(transaction)

    %{
      signed_tx: transaction,
      inputs: inputs,
      outputs: outputs,
      tx_hash: tx_hash,
      tx_type: transaction.tx_type,
      witnesses: transaction.witnesses
    }
  end
end
