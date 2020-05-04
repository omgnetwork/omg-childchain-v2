defmodule Engine.Callbacks.Deposit do
  @moduledoc """
  Contains the business logic of persisting a deposit event and creating the
  appropriate block, transaction and UTXO. For context, a deposit is made
  into its own 'plasma block':

  When you deposit into the network, you send a 'deposit' transaction to the
  contract directly. Upon success, the contract generates a block just for that
  single transaction(incrementing blknum by `1` vs `1000` in blocks submitted
  by the childchain). Example:

    - blknum 1000, this is submitted by the childchain and contains non-deposit transactions
    - blknum 1001-1999, these would be deposits from the contract, in its own blocks (upto 999 deposits)
    - blknum 2000, this is the next submitted childchain block, containing non-deposit transactions
  """

  import Ecto.Changeset

  alias Engine.DB.Block
  alias Engine.DB.Transaction
  alias ExPlasma.Builder

  @type address_binary :: <<_::160>>

  @type tx_hash() :: <<_::256>>

  @type event() :: %{
          root_chain_tx_hash: tx_hash(),
          log_index: non_neg_integer(),
          blknum: non_neg_integer(),
          currency: address_binary(),
          owner: address_binary(),
          amount: non_neg_integer()
        }

  @doc """
  Inserts deposit events, recreating the transaction and forming the associated block,
  transaction, and UTXOs. This will wrap all the build deposits into one DB transaction.
  """
  @spec callback(list()) :: {:ok, map()} | {:error, :atom, any(), any()}
  def callback(events), do: do_callback(Ecto.Multi.new(), events)

  defp do_callback(multi, [event | tail]), do: multi |> build_deposit(event) |> do_callback(tail)
  defp do_callback(multi, []), do: Engine.Repo.transaction(multi)

  defp build_deposit(multi, %{} = event) do
    txbytes =
      [tx_type: 1]
      |> Builder.new()
      |> Builder.add_output(output_guard: event.owner, token: event.currency, amount: event.amount)
      |> ExPlasma.encode()

    confirmed_output =
      txbytes
      |> Transaction.decode()
      |> get_field(:outputs)
      |> hd()

    transaction =
      txbytes
      |> Transaction.decode()
      |> put_change(:outputs, [%{confirmed_output | state: "confirmed"}])

    insertion =
      %Block{}
      |> Block.changeset(%{number: event.blknum, state: "confirmed"})
      |> put_change(:transactions, [transaction])

    Ecto.Multi.insert(multi, "deposit-blknum-#{event.blknum}", insertion,
      on_conflict: :nothing,
      conflict_target: :number
    )
  end
end
