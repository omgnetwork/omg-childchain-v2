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
  alias Engine.DB.ListenerState
  alias Engine.DB.Transaction
  alias Engine.Ethereum.RootChain.Event
  alias ExPlasma.Builder

  @type address_binary :: <<_::160>>

  @type tx_hash() :: <<_::256>>

  @doc """
  Inserts deposit events, recreating the transaction and forming the associated block,
  transaction, and UTXOs. This will wrap all the build deposits into one DB transaction.
  """
  @spec callback(list(Event.t()), atom()) :: {:ok, map()} | {:error, :atom, any(), any()}
  def callback(events, listener),
    do: do_callback(Ecto.Multi.new(), events, %{listener: "#{listener}", height: find_tip_eth_height(events)})

  defp do_callback(multi, [event | tail], synced_height),
    do: multi |> build_deposit(event) |> do_callback(tail, synced_height)

  defp do_callback(multi, [], new_synced_height) do
    multi
    |> Ecto.Multi.run(:synced_height, fn repo, _changes ->
      {:ok, repo.get(ListenerState, "#{new_synced_height.listener}") || %ListenerState{}}
    end)
    |> Ecto.Multi.insert_or_update(:update, &synced_height(&1, new_synced_height))
    |> Engine.Repo.transaction()
  end

  defp build_deposit(multi, %{} = event) do
    tx_bytes =
      [tx_type: 1]
      |> Builder.new()
      |> Builder.add_output(
        output_guard: event.data["depositor"],
        token: event.data["token"],
        amount: event.data["amount"]
      )
      |> ExPlasma.encode()

    confirmed_output =
      tx_bytes
      |> Transaction.decode()
      |> get_field(:outputs)
      |> hd()

    transaction =
      tx_bytes
      |> Transaction.decode()
      |> put_change(:outputs, [%{confirmed_output | state: "confirmed"}])

    insertion =
      %Block{}
      |> Block.changeset(%{number: event.data["blknum"], state: "confirmed"})
      |> put_change(:transactions, [transaction])

    Ecto.Multi.insert(multi, "deposit-blknum-#{event.data["blknum"]}", insertion,
      on_conflict: :nothing,
      conflict_target: :number
    )
  end

  defp find_tip_eth_height(events) do
    Enum.max_by(events, fn event -> event.eth_height end, fn -> 0 end).eth_height
  end

  defp synced_height(%{synced_height: %{height: nil} = synced_height}, new_synced_height) do
    Ecto.Changeset.change(synced_height, new_synced_height)
  end

  defp synced_height(%{synced_height: synced_height}, new_synced_height) do
    case new_synced_height.height > synced_height.height do
      true ->
        Ecto.Changeset.change(synced_height, new_synced_height)

      _ ->
        Ecto.Changeset.change(synced_height, %{})
    end
  end
end
