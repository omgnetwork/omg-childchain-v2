defmodule Engine.Operations.Deposit do
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

  @type address_binary :: <<_::160>>

  @type tx_hash() :: <<_::256>>

  @type event() :: %{
          root_chain_txhash: tx_hash(),
          log_index: non_neg_integer(),
          blknum: non_neg_integer(),
          currency: address_binary(),
          owner: address_binary(),
          amount: non_neg_integer()
        }

  @doc """
  Inserts a deposit event, recreating the transaction and forming the associated block,
  transaction, and UTXOs.
  """
  @spec insert_event(event()) :: %Engine.Transaction{}
  def insert_event(
        %{root_chain_txhash: _, log_index: _, blknum: _, amount: _, currency: _, owner: _} = event
      ) do
    utxo = %ExPlasma.Utxo{
      blknum: event.blknum,
      txindex: 0,
      oindex: 0,
      currency: event.currency,
      owner: event.owner,
      amount: event.amount
    }

    {:ok, deposit} = ExPlasma.Transaction.Deposit.new(utxo)
    tx_bytes = ExPlasma.encode(deposit)

    %Engine.Transaction{}
    |> Engine.Transaction.changeset(tx_bytes)
    |> put_change(:block, %Engine.Block{number: event.blknum})
    |> Engine.Repo.insert()
  end
end
