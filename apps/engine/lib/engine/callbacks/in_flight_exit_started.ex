defmodule Engine.Callbacks.InFlightExitStarted do
  @moduledoc """
  Contains the business logic around recognizing exits on the chain. When a
  in flight exit is detected, we need to ensure the childchain state of Outputs is
  correct and mark the output(the "input") as `exiting` to prevent them from being used.
  """

  @behaviour Engine.Callback

  use Spandex.Decorators

  import Ecto.Query

  alias Ecto.Multi
  alias Engine.Callback
  alias Engine.DB.Output

  @doc """
  Gather all the Output positions in the list of exit events.
  """
  @impl Callback
  @decorate trace(service: :ecto, type: :backend)
  def callback([], _listener), do: {:ok, :noop}

  def callback(events, listener) do
    Multi.new()
    |> Callback.update_listener_height(events, listener)
    |> do_callback([], events)
    |> Engine.Repo.transaction()
  end

  defp do_callback(multi, positions, [event | tail]) do
    %{data: %{"input_utxos_pos" => inputs}} = event
    do_callback(multi, positions ++ inputs, tail)
  end

  defp do_callback(multi, positions, []) do
    query = where(Output.usable(), [output], output.position in ^positions)
    Multi.update_all(multi, :exiting_outputs, query, set: [state: "exiting", updated_at: NaiveDateTime.utc_now()])
  end
end
