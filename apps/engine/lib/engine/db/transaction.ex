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
  alias ExPlasma.Transaction.Recovered

  @type tx_bytes :: binary

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
  @spec decode(tx_bytes, kind: atom()) :: Ecto.Changeset.t()
  def decode(tx_bytes, kind: kind) do
    with {:ok, params} <- tx_bytes_to_map(tx_bytes) do
      params =
        params
        # TODO: Handle fees, load from DB? Buffer period, format?
        |> Map.put(:fees, :no_fees_required)
        |> Map.put(:kind, kind)

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

  defp tx_bytes_to_map(tx_bytes) do
    with {:ok, %Recovered{} = recovered} <- ExPlasma.decode(tx_bytes, :recovered) do
      inputs = ExPlasma.Transaction.get_inputs(recovered)
      outputs = ExPlasma.Transaction.get_outputs(recovered)
      tx_type = ExPlasma.Transaction.get_tx_type(recovered)

      {:ok,
       %{signed_tx: recovered.signed_tx}
       |> Map.put(:inputs, Enum.map(inputs, &Map.from_struct/1))
       |> Map.put(:outputs, Enum.map(outputs, &Map.from_struct/1))
       |> Map.put(:tx_hash, recovered.tx_hash)
       |> Map.put(:witnesses, recovered.witnesses)
       |> Map.put(:tx_type, tx_type)
       |> Map.put(:tx_bytes, tx_bytes)}
    end
  end
end
