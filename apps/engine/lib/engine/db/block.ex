defmodule Engine.DB.Block do
  @moduledoc """
  Ecto schema that represents "Plasma Blocks" that are being submitted from the Childchain to the contracts.
  This holds metadata information and a reference point to associated transactions that are formed into said Block.
  The schema contains the following fields:
  - hash: Is generated when finalizing a block, it is the result of the merkle root hash of all unsigned tx_bytes of transactions it contains
  - nonce: The nonce of the transaction on the rootchain
  - blknum: The plasma block number, it's increased by 1000 for each new block
  - tx_hash: The hash of the transaction containing the the block submission on the rootchain
  - formed_at_ethereum_height: The rootchain height at which the block was formed
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
  import Ecto.Query, only: [from: 2]

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
          nonce: non_neg_integer(),
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
    # blknum = (nonce + 1) * 1000
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
  Changes currently forming block's state to finalizing.
  If there is a non-empty block in state `forming` it changes state to `finalizing`.
  """
  @decorate trace(service: :ecto, type: :backend)
  def finalize_forming_block() do
    result =
      Multi.new()
      |> Multi.run(:block, &get_non_empty_forming_block_for_finalization/2)
      |> Multi.update(:finalizing_block, &finalize_block/1)
      |> Repo.transaction()

    case result do
      {:ok, _} -> :ok
      {:error, :block, :empty_block, %{}} -> :ok
      {:error, :block, :no_forming_block, %{}} -> :ok
      other -> {:error, other}
    end
  end

  @doc """
  Forms blocks awaiting submission.
  For all blocks in finalizing state:
  - transaction fees are attached
  - merkle root hash is calculated
  - state is changed to pending submission
  - sets formed_at_eth_height to ethereum height provided as an argument
  """
  @decorate trace(service: :ecto, type: :backend)
  def prepare_for_submission(eth_height) do
    Multi.new()
    |> Multi.run(:finalizing_blocks, &get_finalizing_blocks/2)
    |> Multi.run(:blocks, &attach_fee_transactions/2)
    |> Multi.run(:blocks_for_submission, fn repo, %{blocks: blocks} ->
      prepare_for_submission(repo, blocks, eth_height)
    end)
    |> Repo.transaction()
  end

  @doc """
  Get a block by its hash.
  """
  @spec get_transactions_by_block_hash(binary()) :: {:ok, t()} | {:error, :no_block_matching_hash}
  def get_transactions_by_block_hash(hash) do
    __MODULE__
    |> Repo.get_by(hash: hash)
    |> Repo.preload(transactions: from(transaction in Transaction, order_by: [asc: transaction.tx_index]))
    |> case do
      nil -> {:error, :no_block_matching_hash}
      block -> {:ok, block}
    end
  end

  def get_forming_block_for_update(repo) do
    # we expect forming block to always exists in the database when this is called
    block = repo.one(BlockQuery.select_forming_block_for_update())

    case block do
      nil -> get_or_insert_forming_block(repo, %{})
      _ -> {:ok, block}
    end
  end

  def get_block_and_tx_index_for_transaction(repo, params, index) do
    key = "current_forming_block-#{index}"
    %{^key => block} = params
    # this is safe as long as we lock on currently forming block
    last_tx_index_for_block = last_tx_index_for_block(repo, block.id)

    # basic version, checking transaction limit is postponed until we get transction fees implemented
    case {last_tx_index_for_block, last_tx_index_for_block >= @max_transaction_in_block} do
      {nil, _} ->
        # the first transaction in a new, empty block needs to start with 0
        {:ok, %{block: block, next_tx_index: 0}}

      {_, true} ->
        # the block is full, we need to start a new block
        {:ok, _} = finalize_block(repo, block)
        {:ok, new_forming_block} = insert_block(repo, %{})
        {:ok, %{block: new_forming_block, next_tx_index: 0}}

      {_, false} ->
        # block is not full yet, tx_index is incremented
        {:ok, %{block: block, next_tx_index: last_tx_index_for_block + 1}}
    end
  end

  def get_last_formed_block_eth_height() do
    Repo.one(BlockQuery.get_last_formed_block_eth_height())
  end

  defp get_non_empty_forming_block_for_finalization(repo, _params) do
    block = repo.one(BlockQuery.select_forming_block_for_update())

    case block do
      nil ->
        {:error, :no_forming_block}

      block ->
        tx_count = tx_count_for_block(repo, block.id)

        case tx_count do
          0 -> {:error, :empty_block}
          _ -> {:ok, block}
        end
    end
  end

  defp get_all(repo, _changeset, new_height, mined_child_block) do
    query = BlockQuery.get_all_for_submission(new_height, mined_child_block)
    {:ok, repo.all(query)}
  end

  defp get_gas_and_submit(repo, %{get_all: plasma_blocks}, new_height, mined_child_block, submit_fn, gas_fn) do
    submitted_blocks = process_submission(repo, plasma_blocks, new_height, mined_child_block, submit_fn, gas_fn)
    {:ok, submitted_blocks}
  end

  defp process_submission(_repo, [], _new_height, _mined_child_block, _submit_fn, gas_fn)
       when is_function(gas_fn) do
    []
  end

  defp process_submission(repo, plasma_blocks, new_height, mined_child_block, submit_fn, gas_fn)
       when is_function(gas_fn) do
    gas =
      gas_fn.()
      |> Map.get(:standard)
      |> Kernel.*(1_000_000_000)
      |> Kernel.round()

    acc = []
    process_submission(repo, plasma_blocks, new_height, mined_child_block, submit_fn, gas, acc)
  end

  defp process_submission(_repo, [], _new_height, _mined_child_block, _submit_fn, _gas, acc) do
    Enum.reverse(acc)
  end

  defp process_submission(repo, [plasma_block | plasma_blocks], new_height, mined_child_block, submit_fn, gas, acc)
       when is_integer(gas) do
    submission_result = submit_fn.(plasma_block.hash, "#{plasma_block.nonce}", "#{gas}")

    Logger.info(
      "Submission result for block #{inspect(plasma_block.hash)} with nonce #{plasma_block.nonce} #{
        inspect(submission_result)
      }"
    )

    case submission_result do
      {:ok, tx_hash} ->
        block =
          plasma_block
          |> BlockChangeset.submitted(%{
            attempts_counter: plasma_block.attempts_counter + 1,
            gas: gas,
            submitted_at_ethereum_height: new_height,
            tx_hash: tx_hash
          })
          |> repo.update!([])

        process_submission(repo, plasma_blocks, new_height, mined_child_block, submit_fn, gas, [block | acc])

      error ->
        # we encountered an error with one of the block submissions
        # we'll stop here and continue later
        _ = Logger.info("Block submission stopped at block with nonce #{plasma_block.nonce}. Error: #{inspect(error)}")
        process_submission(repo, [], new_height, mined_child_block, submit_fn, gas, acc)
    end
  end

  defp insert_block(repo, _) do
    nonce =
      BlockQuery.select_max_nonce()
      |> repo.one()
      |> case do
        nil -> 0
        found_nonce -> found_nonce + 1
      end

    blknum = (nonce + 1) * Configuration.child_block_interval()

    params = %{state: :forming, nonce: nonce, blknum: blknum}

    %__MODULE__{}
    |> BlockChangeset.new_block_changeset(params)
    |> repo.insert(on_conflict: :nothing)
  end

  defp prepare_for_submission(repo, finalizing_blocks, eth_height) do
    do_prepare_for_submission(repo, finalizing_blocks, eth_height, [])
  end

  defp do_prepare_for_submission(_repo, [], _eth_height, acc) do
    {:ok, acc}
  end

  defp do_prepare_for_submission(repo, [block | blocks], eth_height, acc) do
    {:ok, prepared_block} = hash_transactions(repo, block, eth_height)
    do_prepare_for_submission(repo, blocks, eth_height, [prepared_block | acc])
  end

  defp hash_transactions(repo, block, eth_height) do
    hash =
      block.id
      |> fetch_tx_bytes_in_block()
      |> Merkle.root_hash()

    # conflict on hash means block was prepared for submission by other process
    # do nothing then
    block
    |> BlockChangeset.prepare_for_submission(%{hash: hash, formed_at_ethereum_height: eth_height})
    |> repo.update(on_conflict: :nothing)
  end

  defp finalize_block(repo, block) do
    block
    |> BlockChangeset.finalize()
    |> repo.update()
  end

  defp fetch_tx_bytes_in_block(block_id) do
    query = TransactionQuery.fetch_transactions_from_block(block_id)

    transactions =
      query
      |> Repo.all()
      |> Enum.map(fn tx ->
        Transaction.encode_unsigned(tx)
      end)

    _ = Logger.debug("All transactions in a block #{inspect(transactions)}")
    transactions
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

  defp finalize_block(%{block: block}), do: BlockChangeset.finalize(block)

  defp tx_count_for_block(repo, block_id) do
    block_id
    |> TransactionQuery.count_transactions_in_block()
    |> repo.one()
  end

  defp last_tx_index_for_block(repo, block_id) do
    block_id
    |> TransactionQuery.select_max_tx_index_for_block()
    |> repo.one()
  end
end
