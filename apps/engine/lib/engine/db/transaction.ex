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
  alias Engine.Fee
  alias Engine.Repo
  alias ExPlasma.Encoding
  alias ExPlasma.Transaction, as: ExPlasmaTx

  require Logger

  @type tx_bytes :: binary
  @type hex_tx_bytes :: list(binary)

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
  def insert(hex_tx_bytes) do
    case decode(hex_tx_bytes) do
      {:ok, {tx_bytes, decoded}} ->
        [{"1-of-1", tx_bytes, decoded}]
        |> handle_transactions()
        |> Repo.transaction()
        |> case do
          {:ok, result} ->
            {:ok, Map.get(result, "transaction-1-of-1")}

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
  Inserts a new batch of transactions and associates it with currently forming block.
  If including a new transaction in forming block violates maximum number of transaction per block
  then the transaction is associated with a newly inserted forming block.
  """
  def insert_batch(txs_bytes) do
    case decode_batch(txs_bytes) do
      {:ok, batch} ->
        batch
        |> handle_transactions()
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

  defp handle_transactions(batch) do
    all_fees = load_fees()

    batch
    |> Enum.reduce(Multi.new(), fn {index, tx_bytes, decoded}, multi ->
      {:ok, fees} = load_fee(all_fees, decoded.tx_type)

      changeset = TransactionChangeset.new_transaction_changeset(%__MODULE__{}, tx_bytes, decoded, fees)

      block_with_next_tx_index = "block_with_next_tx_index-#{index}"

      multi
      |> Multi.run("current_forming_block-#{index}", fn repo, _ -> Block.get_forming_block_for_update(repo) end)
      |> Multi.run(block_with_next_tx_index, fn repo, params ->
        Block.get_block_and_tx_index_for_transaction(repo, params, index)
      end)
      |> Multi.insert("transaction-#{index}", fn %{^block_with_next_tx_index => block_with_next_tx_index} ->
        TransactionChangeset.set_blknum_and_tx_index(changeset, block_with_next_tx_index)
      end)
    end)
  end

  @spec decode(hex_tx_bytes) :: {:ok, ExPlasma.Transaction.t()} | {:error, atom()}
  defp decode(hex_tx_bytes) do
    with {:ok, tx_bytes} <- Encoding.to_binary(hex_tx_bytes),
         {:ok, decoded} <- ExPlasma.decode(tx_bytes),
         {:ok, recovered} <- ExPlasmaTx.with_witnesses(decoded) do
      {:ok, {tx_bytes, recovered}}
    end
  end

  @spec decode_batch(list(hex_tx_bytes)) :: {:ok, list(ExPlasma.Transaction.t())} | {:error, atom()}
  defp decode_batch(hexs_tx_bytes) do
    acc = []
    index = 0
    decode_batch(hexs_tx_bytes, acc, index)
  end

  defp decode_batch([], acc, _) do
    {:ok, Enum.reverse(acc)}
  end

  defp decode_batch([hex_tx_bytes | hexs_tx_bytes], acc, index) do
    with {:ok, tx_bytes} <- Encoding.to_binary(hex_tx_bytes),
         {:ok, decoded} <- ExPlasma.decode(tx_bytes),
         {:ok, recovered} <- ExPlasmaTx.with_witnesses(decoded) do
      decode_batch(hexs_tx_bytes, [{index, tx_bytes, recovered} | acc], index + 1)
    end
  end

  defp load_fees() do
    {:ok, all_fees} = Fee.accepted_fees()
    all_fees
  end

  defp load_fee(all_fees, type) do
    fees_for_type = Map.get(all_fees, type, {:error, :invalid_transaction_type})
    {:ok, fees_for_type}
  end
end
