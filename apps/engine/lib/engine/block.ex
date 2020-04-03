defmodule Engine.Block do
  @moduledoc """
  Represent a block of transactions that will be submitted to the contracts.
  """

  use Ecto.Schema
  import Ecto.Query, only: [from: 2]

  schema "blocks" do
    field(:hash, :binary)
    field(:number, :integer)

    has_many(:transactions, Engine.Transaction)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Forms a pending block record based on the existing pending transactions. This
  attaches free transactions into a new block, awaiting for submission to the contract
  later on.
  """
  @spec form_block() :: {:ok, tuple()} | {:error, any()}
  def form_block() do
    with {:ok, block} <- insert_new_block(),
         {total_records, _} <- update_pending_transactions(block) do
      {:ok, {block.id, total_records}}
    end
  end

  # Create a new block for us to associate with.
  defp insert_new_block(), do: Engine.Repo.insert(%__MODULE__{})

  # Associate all 'free' pending transactions
  # to the given block
  defp update_pending_transactions(block) do
    Engine.Repo.update_all(query_for_unassociated_txn_ids(),
      set: [
        block_id: block.id,
        updated_at: NaiveDateTime.utc_now()
      ]
    )
  end

  # Since we use `Repo.update_all/2`, we need to return
  # it a list of all transaction IDs we want to associate with.
  defp query_for_unassociated_txn_ids(),
    do: from(t in Engine.Transaction, where: is_nil(t.block_id), select: t.id)
end
