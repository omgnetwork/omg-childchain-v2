defmodule Engine.Callbacks.ExitStarted do
  @moduledoc """
  Contains the business logic around recognizing exits on the chain. When a
  standard exit is detected, we need to ensure the childchain state of Outputs is
  correct and mark them as `exiting` to prevent them from being used.
  """

  @behaviour Engine.Callback

  use Spandex.Decorators

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
    %{data: %{"utxo_pos" => position}} = event
    do_callback(multi, positions ++ [position], tail)
  end

  defp do_callback(multi, positions, []), do: Output.exit(multi, positions)
end
