defmodule Engine.Callbacks.Piggyback do
  @moduledoc """
  Contains the business logic around recognizing exits on the chain. When a
  standard exit is detected, we need to ensure the childchain state of Outputs is
  correct and mark them as `exiting` to prevent them from being used.
  """

  import Ecto.Changeset, only: [change: 2, get_field: 2]

  alias Engine.DB.Output
  alias Engine.DB.Transaction

  @type event() :: %{
          eth_height: non_neg_integer(),
          event_signature: String.t(),
          log_index: non_neg_integer(),
          omg_data: map(),
          output_index: non_neg_integer(),
          owner: binary(),
          root_chain_txhash: binary(),
          tx_hash: binary()
        }

  @doc """
  Gather all the Output positions in the list of exit events.
  """
  @spec callback(list()) :: {:ok, map()} | {:error, :atom, any(), any()}
  def callback(events), do: do_callback(Ecto.Multi.new(), events)

  defp do_callback(multi, [event | tail]), do: multi |> piggyback_output(event) |> do_callback(tail)
  defp do_callback(multi, []), do: Engine.Repo.transaction(multi)

  # A `txhash` isn't unique, so we just kinda take the `txhash` as a short-hand
  # to figure out which `txhash` it could possibly be with the given `oindex`.
  # Additionally, in the old system, 'spent' outputs were just removed from the system.
  # For us, we keep track of the history to some degree(e.g state change).
  #
  # See: https://github.com/omisego/elixir-omg/blob/8189b812b4b3cf9256111bd812235fb342a6fd50/apps/omg/lib/omg/state/utxo_set.ex#L81
  defp piggyback_output(multi, %{omg_data: %{piggyback_type: :input}} = event), do: do_piggyback(multi, :inputs, event)
  defp piggyback_output(multi, %{omg_data: %{piggyback_type: :output}} = event), do: do_piggyback(multi, :outputs, event)

  defp do_piggyback(multi, type, %{output_index: oindex, tx_hash: tx_hash}) do
    transaction =
      tx_hash
      |> Transaction.find_by_txhash()
      |> Engine.Repo.one()
      |> Engine.Repo.preload(type)

    case transaction do
      nil ->
        multi

      transaction ->
        case transaction |> Map.get(type) |> Enum.at(oindex) do
          %Output{state: "confirmed"} = output ->
            changeset = change(output, state: "piggybacked")
            position = get_field(changeset, :position)
            Ecto.Multi.update(multi, "piggyback-#{type}-#{position}", changeset)

          _ ->
            multi
        end
    end
  end
end
