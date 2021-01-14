defmodule Engine.DB.Transaction do
  @moduledoc """
  The Transaction record. This is one of the main entry points for the system, specifically accepting
  transactions into the Childchain as `tx_bytes`. This expands those bytes into:
  * `tx_bytes` - A binary of a transaction encoded by RLP.
  * `inputs`  - The outputs that the transaction is acting on, and changes state e.g marked as "spent"
  * `outputs` - The newly created outputs
  More information is contained in the `tx_bytes`. However, to keep the Childchain _lean_, we extract
  data onto the record as needed.
  The schema contains the following fields:
  - tx_bytes: The signed bytes submited by users
  - tx_hash: The keccak hash of the transaction
  - tx_type: The type of the transaction, this is an integer. ie: `1` for payment v1 transactions, `3` for fee transactions
  - tx_index: index of the transaction in a block
  Virtual fields used for convenience and validation:
  - witnesses: Avoid decoding/parsing signatures mutiple times along validation process
  - signed_tx: Avoid calling decode(tx_bytes) multiple times along the validation process
  Note that with the current implementation, fields virtual fields are not populated when loading record from the DB
  """

  use Ecto.Schema

  alias __MODULE__.TransactionChangeset
  alias Ecto.Multi
  alias Engine.DB.Block
  alias Engine.DB.Output
  alias Engine.DB.TransactionFee
  alias Engine.Configuration
  alias Engine.Fee
  alias Engine.Repo
  alias ExPlasma.Transaction, as: ExPlasmaTx

  require Logger

  @type tx_bytes :: binary

  @type t() :: %{
          block: Block.t(),
          block_id: pos_integer(),
          tx_index: non_neg_integer(),
          id: pos_integer(),
          inputs: list(Output.t()),
          inserted_at: DateTime.t(),
          outputs: list(Output.t()),
          signed_tx: ExPlasma.Transaction.t() | nil,
          tx_bytes: binary(),
          tx_hash: <<_::256>>,
          tx_type: pos_integer(),
          updated_at: DateTime.t(),
          witnesses: binary()
        }

  @timestamps_opts [inserted_at: :node_inserted_at, updated_at: :node_updated_at]

  schema "transactions" do
    field(:tx_bytes, :binary)
    field(:tx_hash, :binary)
    field(:tx_type, :integer)
    field(:tx_index, :integer)

    # Virtual fields used for convenience and validation
    # Avoid decoding/parsing signatures mutiple times along validation process
    field(:witnesses, {:array, :string}, virtual: true)
    # Avoid calling decode(tx_bytes) multiple times along the validation process
    field(:signed_tx, :map, virtual: true)

    belongs_to(:block, Block)
    has_many(:inputs, Output, foreign_key: :spending_transaction_id)
    has_many(:outputs, Output, foreign_key: :creating_transaction_id)
    has_many(:fees, TransactionFee, foreign_key: :transaction_id)

    field(:inserted_at, :utc_datetime)
    field(:updated_at, :utc_datetime)

    timestamps()
  end

  @doc """
  Query a transaction by the given `field`.
  Also preload given `preloads`
  """
  def get_by(field, preloads) do
    __MODULE__
    |> Repo.get_by(field)
    |> Repo.preload(preloads)
  end

  @spec encode_unsigned(t()) :: binary()
  def encode_unsigned(transaction) do
    {:ok, tx} = ExPlasma.decode(transaction.tx_bytes, signed: false)

    ExPlasma.encode!(tx, signed: false)
  end

  @doc """
  Inserts a new transaction and associates it with currently forming block.
  If including a new transaction in forming block violates maximum number of transaction per block
  then the transaction is associated with a newly inserted forming block.
  """
  def insert(tx_bytes) do
    case decode(tx_bytes) do
      {:ok, decoded} ->
        {:ok, fees} = load_fees(decoded.tx_type)
        decoded_with_fees = Map.put(decoded, :fees, fees)
        changeset = TransactionChangeset.new_transaction_changeset(%__MODULE__{}, decoded_with_fees)

        Multi.new()
        |> Multi.run(:current_forming_block, &Block.get_forming_block_for_update/2)
        |> Multi.run(:block_with_next_tx_index, &Block.get_block_and_tx_index_for_transaction/2)
        |> Multi.insert(:transaction, fn %{block_with_next_tx_index: block_with_next_tx_index} ->
          TransactionChangeset.set_blknum_and_tx_index(changeset, block_with_next_tx_index)
        end)
        |> Repo.transaction()
        |> case do
          {:ok, _} = result ->
            result

          {:error, _, changeset, _} ->
            _ = Logger.error("Error when inserting transaction changeset #{inspect(changeset)}")
            {:error, changeset}

          error ->
            _ = Logger.error("Error when inserting transaction #{inspect(error)}")
            error
        end

      decode_error ->
        _ = Logger.error("Error when inserting transaction decode_error #{inspect(decode_error)}")
        decode_error
    end
  end

  @doc """
  Inserts a fee transaction associated with a given block and transaction index
  """
  def insert_fee_transaction(repo, currency_with_amount, block, fee_tx_index) do
    currency_with_amount
    |> TransactionChangeset.new_fee_transaction_changeset(block)
    |> TransactionChangeset.set_blknum_and_tx_index(%{block: block, next_tx_index: fee_tx_index})
    |> repo.insert()
  end

  @spec decode(tx_bytes) :: {:ok, Ecto.Changeset.t()} | {:error, atom()}
  defp decode(tx_bytes) do
    with {:ok, decoded} <- ExPlasma.decode(tx_bytes),
         {:ok, recovered} <- ExPlasmaTx.with_witnesses(decoded) do
      params =
        recovered
        |> recovered_to_map()
        |> Map.put(:tx_bytes, tx_bytes)

      {:ok, params}
    end
  end

  defp load_fees(type) do
    case Configuration.collect_fees() do
      "0" ->
        {:ok, :no_fees_required}

      _ ->
        {:ok, all_fees} = Fee.accepted_fees()
        fees_for_type = Map.get(all_fees, type, {:error, :invalid_transaction_type})
        {:ok, fees_for_type}
    end
  end

  defp recovered_to_map(transaction) do
    inputs = Enum.map(transaction.inputs, &Map.from_struct/1)
    outputs = Enum.map(transaction.outputs, &Map.from_struct/1)
    {:ok, tx_hash} = ExPlasma.hash(transaction)

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
