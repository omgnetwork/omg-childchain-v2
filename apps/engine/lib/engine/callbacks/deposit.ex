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

  @behaviour Engine.Callback

  use Spandex.Decorators

  import Ecto.Changeset

  alias Ecto.Multi
  alias Engine.Callback
  alias Engine.DB.Transaction
  alias ExPlasma.Builder

  @doc """
  Inserts deposit events, recreating the transaction and forming the associated block,
  transaction, and UTXOs. This will wrap all the build deposits into one DB transaction.
  """
  @impl Callback
  @decorate trace(service: :ecto, type: :backend)
  def callback(events, listener) do
    Multi.new()
    |> Callback.update_listener_height(events, listener)
    |> do_callback(events)
    |> Engine.Repo.transaction()
  end

  defp do_callback(multi, [event | tail]), do: multi |> build_deposit(event) |> do_callback(tail)
  defp do_callback(multi, []), do: multi

  defp build_deposit(multi, %{} = event) do
    tx_bytes =
      ExPlasma.payment_v1()
      |> Builder.new()
      |> Builder.add_output(
        output_guard: event.data["depositor"],
        token: event.data["token"],
        amount: event.data["amount"]
      )
      |> ExPlasma.encode!()

    {:ok, changeset} = Transaction.decode(tx_bytes, Transaction.kind_deposit())

    changeset_with_block_number =
      changeset
      |> put_change(:deposit_block_number, event.data["blknum"])
      |> put_change(:deposit_tx_hash, changeset.changes.tx_hash)
      |> put_change(:tx_hash, nil)

    Ecto.Multi.insert(multi, "deposit-blknum-#{event.data["blknum"]}", changeset_with_block_number,
      on_conflict: :nothing,
      conflict_target: [:deposit_tx_hash, :deposit_block_number]
    )
  end
end
