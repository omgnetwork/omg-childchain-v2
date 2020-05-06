defmodule Engine.Callbacks.Piggyback do
  @moduledoc """
  Contains the business logic around recognizing exits on the chain. When a
  standard exit is detected, we need to ensure the childchain state of Outputs is
  correct and mark them as `exiting` to prevent them from being used.
  """

  @behaviour Engine.Callback

  import Ecto.Changeset, only: [change: 2, get_field: 2]

  alias Ecto.Multi
  alias Engine.Callback
  alias Engine.DB.Output
  alias Engine.DB.Transaction

  @doc """
  Gather all the Output positions in the list of exit events.
  """
  @impl Callback
  def callback(events, listener) do
    Multi.new()
    |> Callback.update_listener_height(events, listener)
    |> do_callback(events)
  end

  defp do_callback(multi, [event | tail]), do: multi |> piggyback(event) |> do_callback(tail)
  defp do_callback(multi, []), do: Engine.Repo.transaction(multi)

  # A `tx_hash` isn't unique, so we just kinda take the `tx_hash` as a short-hand
  # to figure out which `tx_hash` it could possibly be with the given `oindex`.
  # Additionally, in the old system, 'spent' outputs were just removed from the system.
  # For us, we keep track of the history to some degree(e.g state change).
  #
  # See: https://github.com/omisego/elixir-omg/blob/8189b812b4b3cf9256111bd812235fb342a6fd50/apps/omg/lib/omg/state/utxo_set.ex#L81
  defp piggyback(multi, %{data: %{"input_index" => index}} = event) do
    do_piggyback(multi, :inputs, index: index, tx_hash: event.data["tx_hash"])
  end

  defp piggyback(multi, %{data: %{"output_index" => index}} = event) do
    do_piggyback(multi, :outputs, index: index, tx_hash: event.data["tx_hash"])
  end

  defp do_piggyback(multi, type, index: index, tx_hash: tx_hash) do
    transaction =
      tx_hash
      |> Transaction.find_by_tx_hash()
      |> Engine.Repo.one()
      |> Engine.Repo.preload(type)

    case transaction do
      nil ->
        multi

      transaction ->
        case transaction |> Map.get(type) |> Enum.at(index) do
          %Output{state: "confirmed"} = output ->
            changeset = change(output, state: "piggybacked")
            position = get_field(changeset, :position)
            Multi.update(multi, "piggyback-#{type}-#{position}", changeset)

          _ ->
            multi
        end
    end
  end
end
