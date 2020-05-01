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

  alias Engine.Ethereum.RootChain.Event
  alias Engine.Transaction
  alias ExPlasma.Transaction.Deposit, as: ExDeposit

  @type address_binary :: <<_::160>>

  @type tx_hash() :: <<_::256>>

  @doc """
  Inserts deposit events, recreating the transaction and forming the associated block,
  transaction, and UTXOs. This will wrap all the build deposits into one DB transaction.
  """
  @spec callback(list(Event.t())) :: {:ok, map()} | {:error, :atom, any(), any()}
  def callback(events), do: do_callback(Ecto.Multi.new(), events)

  defp do_callback(multi, [event | tail]), do: multi |> build_deposit(event) |> do_callback(tail)
  defp do_callback(multi, []), do: Engine.Repo.transaction(multi)

  defp build_deposit(multi, %{} = event) do
    utxo = %ExPlasma.Utxo{
      blknum: event.data["blknum"],
      txindex: 0,
      oindex: 0,
      currency: event.data["token"],
      owner: event.data["depositor"],
      amount: event.data["amount"]
    }

    {:ok, deposit} = ExDeposit.new(utxo)
    tx_bytes = ExPlasma.encode(deposit)

    changeset =
      %Transaction{}
      |> Transaction.changeset(tx_bytes)
      |> put_change(:block, %Engine.Block{number: event.data["blknum"]})

    Ecto.Multi.insert(multi, "deposit-blknum-#{event.data["blknum"]}", changeset)
  end
end
