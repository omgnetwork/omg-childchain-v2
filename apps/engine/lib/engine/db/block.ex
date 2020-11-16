defmodule Engine.DB.Block do
  @moduledoc """
  Ecto schema that represents "Plasma Blocks" that are being submitted from the Childchain to the contracts.
  This holds metadata information and a reference point to associated transactions that are formed into said Block.
  The schema contains the following fields:
  - hash: Is generated when finalizing a block, it is the result of the merkle root hash of all unsigned tx_bytes of transactions it contains
  - nonce: The nonce of the transaction on the rootchain
  - blknum: The plasma block number, it's increased by 1000 for each new block
  - tx_hash: The hash of the transaction containing the the block submission on the rootchain
  - formed_at_ethereum_height: The rootchain height at wish the block was formed
  - submitted_at_ethereum_height: The rootchain height at wish the block was submitted
  - gas: The gas price used for the submission
  - attempts_counter: The number of submission attempts
  - state:
      - :forming - block accepts transactions, at most one forming block is allowed in the database
      - :finalizing - block does not accept transactions, awaits for calculating hash
      - :pending_submission - block no longer accepts for transaction and is waiting for being submitted to the root chain
      - :submitted - block was submitted to the root chain
      - :confirmed - block is confirmed on the root chain
  """

  use Ecto.Schema
  use Spandex.Decorators

  alias __MODULE__.BlockChangeset
  alias __MODULE__.BlockQuery
  alias Ecto.Multi
  alias Engine.Configuration
  alias Engine.DB.Transaction
  alias Engine.DB.Transaction.TransactionQuery
  alias Engine.DB.TransactionFee.TransactionFeeQuery
  alias Engine.Repo
  alias ExPlasma.Merkle

  require Logger

  @max_transaction_in_block 65_000

  @type t() :: %{
          hash: binary(),
          state: :forming | :finalizing | :pending_submission | :submitted | :confirmed,
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
  @timestamps_opts [inserted_at: :node_inserted_at, updated_at: :node_updated_at]

  schema "blocks" do
    field(:hash, :binary)
    field(:state, Ecto.Atom)
    # nonce = max(nonce) + 1
    field(:nonce, :integer)
    # blknum = nonce * 1000
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

    field(:inserted_at, :utc_datetime)
    field(:updated_at, :utc_datetime)

    timestamps()
  end

  def state_forming(), do: :forming

  def state_finalizing(), do: :finalizing

  def state_pending_submission(), do: :pending_submission

  def state_submitted(), do: :submitted

  def state_confirmed(), do: :confirmed

  @spec get_all_and_submit(pos_integer(), pos_integer(), function(), function()) :: transaction_result_t()
  def get_all_and_submit(new_height, mined_child_block, submit_fn, gas_fn) do
    Multi.new()
    |> Multi.run(:get_all, fn repo, changeset ->
      get_all(repo, changeset, new_height, mined_child_block)
    end)
    |> Multi.run(:get_gas_and_submit, fn repo, changeset ->
      get_gas_and_submit(repo, changeset, new_height, mined_child_block, submit_fn, gas_fn)
    end)
    |> Repo.transaction()
  end

  @doc """
  Forms a block awaiting submission.
  """
  @decorate trace(service: :ecto, type: :backend)
  def form() do
    Multi.new()
    |> Multi.run(:block, &get_forming_block_for_update/2)
    |> Multi.run(:block_for_submission, fn repo, %{block: block} -> hash_transactions(repo, block) end)
    |> Multi.run(:new_forming_block, &insert_block/2)
    |> Repo.transaction()
  end

  @doc """
  Forms blocks awaiting submission.
  For all blocks in finalizing state:
  - transaction fees are attached
  - merkle root hash is calculated
  - state is changed to pending submission
  """
  def prepare_for_submission() do
    Multi.new()
    |> Multi.run(:finalizing_blocks, &get_finalizing_blocks/2)
    |> Multi.run(:blocks, &attach_fee_transactions/2)
    |> Multi.run(:blocks_for_submission, &prepare_for_submission/2)
    |> Repo.transaction()
  end

  @doc """
  Get a block by its hash.
  """
  @spec get_by_hash(binary(), atom() | list(atom())) :: {:ok, t()} | {:error, :no_block_matching_hash}
  def get_by_hash(hash, preloads) do
    __MODULE__
    |> Repo.get_by(hash: hash)
    |> Repo.preload(preloads)
    |> case do
      nil -> {:error, :no_block_matching_hash}
      block -> {:ok, block}
    end
  end

  def get_forming_block_for_update(repo, _params) do
    # we expect forming block to always exists in the database when this is called
    block = repo.one(BlockQuery.select_forming_block_for_update())

    case block do
      nil -> get_or_insert_forming_block(repo, %{})
      _ -> {:ok, block}
    end
  end

  def get_block_and_tx_index_for_transaction(repo, params) do
    %{current_forming_block: block} = params
    # this is safe as long as we lock on currently forming block
    last_tx_index = repo.one(TransactionQuery.select_max_tx_index_for_block(block.id)) || -1

    # basic version, checking transaction limit is postponed until we get transction fees implemented
    case last_tx_index >= @max_transaction_in_block do
      true ->
        {:ok, _} = finalize_block(repo, block)
        {:ok, new_forming_block} = insert_block(repo, %{})
        {:ok, %{block: new_forming_block, next_tx_index: 0}}

      false ->
        {:ok, %{block: block, next_tx_index: last_tx_index + 1}}
    end
  end

  defp get_all(repo, _changeset, new_height, mined_child_block) do
    query = BlockQuery.get_all(new_height, mined_child_block)
    {:ok, repo.all(query)}
  end

  defp get_gas_and_submit(repo, %{get_all: plasma_blocks}, new_height, mined_child_block, submit_fn, gas_fn) do
    :ok = process_submission(repo, plasma_blocks, new_height, mined_child_block, submit_fn, gas_fn)
    {:ok, []}
  end

  defp process_submission(_repo, [], _new_height, _mined_child_block, _submit_fn, _gas_fn) do
    :ok
  end

  defp process_submission(repo, [plasma_block | plasma_blocks], new_height, mined_child_block, submit_fn, gas_fn) do
    # getting appropriate gas here
    gas = gas_fn.()

    case submit_fn.(plasma_block.hash, plasma_block.nonce, gas) do
      :ok ->
        plasma_block
        |> BlockChangeset.submitted(%{
          attempts_counter: plasma_block.attempts_counter + 1,
          gas: gas,
          submitted_at_ethereum_height: new_height
        })
        |> repo.update!([])

        process_submission(repo, plasma_blocks, new_height, mined_child_block, submit_fn, gas_fn)

      error ->
        # we encountered an error with one of the block submissions
        # we'll stop here and continue later
        _ = Logger.error("Block submission stopped at block with nonce #{plasma_block.nonce}. Error: #{inspect(error)}")
        process_submission(repo, [], new_height, mined_child_block, submit_fn, gas_fn)
    end
  end

  defp insert_block(repo, _) do
    nonce =
      BlockQuery.select_max_nonce()
      |> Repo.one()
      |> case do
        nil -> 1
        found_nonce -> found_nonce + 1
      end

    blknum = nonce * Configuration.child_block_interval()

    params = %{state: :forming, nonce: nonce, blknum: blknum}

    %__MODULE__{}
    |> BlockChangeset.new_block_changeset(params)
    |> repo.insert(on_conflict: :nothing)
  end

  defp prepare_for_submission(repo, blocks) do
    %{blocks: blocks} = blocks

    prepared_blocks =
      Enum.map(blocks, fn block ->
        {:ok, prepared_block} = hash_transactions(repo, block)
        prepared_block
      end)

    {:ok, prepared_blocks}
  end

  defp hash_transactions(repo, block) do
    hash =
      block.id
      |> fetch_tx_bytes_in_block()
      |> Merkle.root_hash()

    # conflict on hash means block was prepared for submission by other process
    # do nothing then
    block
    |> BlockChangeset.prepare_for_submission(%{hash: hash})
    |> repo.update(on_conflict: :nothing)
  end

  defp finalize_block(repo, block) do
    block
    |> BlockChangeset.finalize()
    |> repo.update()
  end

  defp fetch_tx_bytes_in_block(block_id) do
    query = TransactionQuery.fetch_transactions_from_block(block_id)

    query
    |> Repo.all()
    |> Enum.map(fn tx ->
      Transaction.encode_unsigned(tx)
    end)
  end

  defp get_or_insert_forming_block(repo, params) do
    {:ok, _} = insert_block(repo, params)
    {:ok, repo.one(BlockQuery.select_forming_block_for_update())}
  end

  defp get_finalizing_blocks(repo, _params) do
    finalizing_blocks = repo.all(BlockQuery.select_finalizing_blocks())
    {:ok, finalizing_blocks}
  end

  defp attach_fee_transactions(repo, params) do
    finalizing_blocks = params.finalizing_blocks
    :ok = Enum.each(finalizing_blocks, &attach_fee_transactions_to_block(repo, &1))

    {:ok, finalizing_blocks}
  end

  defp attach_fee_transactions_to_block(repo, block) do
    fees_by_currency =
      block.id
      |> TransactionFeeQuery.get_fees_for_block()
      |> repo.all()

    max_non_fee_transaction_tx_index = repo.one(TransactionQuery.select_max_non_fee_transaction_tx_index(block.id))

    # inserts fee transaction with corresponding transaction index
    # fee transaction indexes are consecutive natural numbers
    # starting with the next number after `max_non_fee_transaction_tx_index`
    fees_by_currency
    |> Enum.with_index()
    |> Enum.each(fn {currency_with_amount, index} ->
      fee_tx_index = max_non_fee_transaction_tx_index + index + 1
      {:ok, _} = Transaction.insert_fee_transaction(repo, currency_with_amount, block, fee_tx_index)
      :ok
    end)
  end
end
