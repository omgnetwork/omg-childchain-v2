defmodule Engine.Callbacks.Deposit do
  @moduledoc """
  Contains the business logic of persisting a deposit event and creating the
  appropriate UTXO.

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

  alias Ecto.Multi
  alias Engine.Callback
  alias Engine.DB.Output
  alias Engine.Repo
  alias ExPlasma.Output.Position

  @doc """
  Inserts deposit events, forming the associated UTXOs.
  This will wrap all the build deposits into one DB transaction.
  """
  @impl Callback
  @decorate trace(service: :ecto, type: :backend)
  def callback([], _listener), do: {:ok, :noop}

  def callback(events, listener) do
    Multi.new()
    |> Callback.update_listener_height(events, listener)
    |> do_callback(events)
    |> Repo.transaction()
  end

  defp do_callback(multi, [event | tail]), do: multi |> build_deposit(event) |> do_callback(tail)
  defp do_callback(multi, []), do: multi

  defp build_deposit(multi, event) do
    output_id = Position.new(event.data["blknum"], 0, 0)

    output_params = %{
      state: "confirmed",
      output_type: ExPlasma.payment_v1(),
      output_data: %{
        output_guard: event.data["depositor"],
        token: event.data["token"],
        amount: event.data["amount"]
      },
      output_id: output_id
    }

    output = Output.changeset(%Output{}, output_params)

    Ecto.Multi.insert(multi, "deposit-output-#{output_id.position}", output,
      on_conflict: :nothing,
      conflict_target: :position
    )
  end
end
