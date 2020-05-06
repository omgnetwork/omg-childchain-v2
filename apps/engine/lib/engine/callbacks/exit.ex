defmodule Engine.Callbacks.Exit do
  @moduledoc """
  Contains the business logic around recognizing exits on the chain. When a
  standard exit is detected, we need to ensure the childchain state of Outputs is
  correct and mark them as `exiting` to prevent them from being used.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias Engine.Callback
  alias Engine.DB.Output

  @doc """
  Gather all the Output positions in the list of exit events.
  """
  @impl Callback
  def callback(events, listener) do
    Multi.new()
    |> Callback.update_listener_height(events, listener)
    |> do_callback([], events)
  end

  defp do_callback(multi, positions, [event | tail]) do
    %{call_data: %{utxo_pos: position}} = event
    do_callback(multi, positions ++ [position], tail)
  end

  defp do_callback(multi, positions, []) do
    query = where(Output.usable(), [output], output.position in ^positions)

    multi
    |> Multi.update_all(:exiting_outputs, query, set: [state: "exited", updated_at: NaiveDateTime.utc_now()])
    |> Engine.Repo.transaction()
  end
end
