defmodule Engine.Callbacks.Piggyback do
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
  alias Engine.DB.Transaction

  @doc """
  Gather all the Output positions in the list of exit events.
  """
  @impl Callback
  @decorate trace(service: :ecto, type: :backend)
  def callback([], _listener), do: {:ok, :noop}

  def callback(events, listener) do
    Multi.new()
    |> Callback.update_listener_height(events, listener)
    |> do_callback(events)
    |> Engine.Repo.transaction()
  end

  defp do_callback(multi, [event | tail]), do: multi |> piggyback(event) |> do_callback(tail)
  defp do_callback(multi, []), do: multi

  # In the old system, 'spent' outputs were just removed from the system.
  # For us, we keep track of the history to some degree(e.g state change).
  #
  # See: https://github.com/omisego/elixir-omg/blob/8189b812b4b3cf9256111bd812235fb342a6fd50/apps/omg/lib/omg/state/utxo_set.ex#L81
  #
  # We shouldn't have to do anything with input being piggybacked
  # See: https://github.com/omgnetwork/elixir-omg/blob/652023025f0cc53370e77802af5659c72eab0592/docs/exit_validation.md#notes-on-the-child-chain-server
  defp piggyback(multi, %{data: %{"input_index" => _index}}), do: multi

  defp piggyback(multi, %{data: %{"output_index" => index, "tx_hash" => tx_hash}}) do
    [tx_hash: tx_hash]
    |> Transaction.get_by(:outputs)
    |> get_output(index)
    |> set_as_piggybacked(multi, tx_hash)
  end

  defp get_output(nil, _index), do: nil
  defp get_output(transaction, index), do: Enum.at(transaction.outputs, index)

  defp set_as_piggybacked(%Output{state: :confirmed} = output, multi, tx_hash) do
    changeset = Output.piggyback(output)
    Multi.update(multi, "piggyback-#{tx_hash}-#{output.position}", changeset)
  end

  defp set_as_piggybacked(_, multi, _tx_hash), do: multi
end
