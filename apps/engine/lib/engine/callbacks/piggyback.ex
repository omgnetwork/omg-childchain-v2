defmodule Engine.Callbacks.Piggyback do
  @moduledoc """
  Contains the business logic around recognizing exits on the chain. When a
  standard exit is detected, we need to ensure the childchain state of Outputs is
  correct and mark them as `exiting` to prevent them from being used.
  """

  @behaviour Engine.Callback

  use Spandex.Decorators

  import Ecto.Changeset, only: [change: 2]

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
  defp piggyback(multi, %{data: %{"input_index" => index, "tx_hash" => tx_hash}}) do
    do_piggyback(multi, :inputs, index, tx_hash)
  end

  defp piggyback(multi, %{data: %{"output_index" => index, "tx_hash" => tx_hash}}) do
    do_piggyback(multi, :outputs, index, tx_hash)
  end

  defp do_piggyback(multi, type, index, tx_hash) do
    tx_hash
    |> Transaction.query_by_tx_hash()
    |> Engine.Repo.one()
    |> Engine.Repo.preload(type)
    |> get_output(type, index)
    |> set_as_piggybacked(multi, tx_hash, type)
  end

  defp get_output(nil, _type, _index), do: nil
  defp get_output(transaction, type, index), do: transaction |> Map.get(type) |> Enum.at(index)

  defp set_as_piggybacked(%Output{state: "confirmed"} = output, multi, tx_hash, type) do
    changeset = Output.piggyback(output)
    Multi.update(multi, "piggyback-#{tx_hash}-#{type}-#{output.position}", changeset)
  end

  defp set_as_piggybacked(_, multi, _tx_hash, _type), do: multi
end
