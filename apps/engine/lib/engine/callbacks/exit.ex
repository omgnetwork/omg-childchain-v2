defmodule Engine.Callbacks.Exit do
  @moduledoc """
  Contains the business logic around recognizing exits on the chain. When a
  standard exit is detected, we need to ensure the childchain state of UTXOs is
  correct and mark them as `exiting` to prevent them from being used.
  """

  import Ecto.Query, only: [from: 2]

  @doc """
  Gather all the UTXO positions in the list of exit events.
  """
  # @spec callback(map()) ::
  def callback(events), do: do_callback([], events)

  defp do_callback(positions, [event | tail]),
    do: positions |> mark_exiting_utxo(event) |> do_callback(tail)

  defp do_callback(positions, []), do: update_positions_as_exiting(positions)

  # Grab's all the UTXO positions.
  #
  # TODO: Should we be checking that the owner matches with what
  # we have recorded in DB?
  #
  # TODO: Should we be checking that the UTXO has not been spent yet?
  defp mark_exiting_utxo(positions, %{} = event) do
    %{call_data: %{utxo_pos: position}} = event
    positions ++ [position]
  end

  defp update_positions_as_exiting(positions) do
    query =
      from(u in Engine.Utxo,
        where: u.pos in ^positions and u.state not in ["spent", "exited"]
      )

    Engine.Repo.update_all(query,
      set: [
        state: "exited",
        updated_at: NaiveDateTime.utc_now()
      ]
    )
  end
end
