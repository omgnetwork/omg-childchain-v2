defmodule Engine.Callbacks.Piggyback do
  @moduledoc """
  Contains the business logic around recognizing exits on the chain. When a
  standard exit is detected, we need to ensure the childchain state of Outputs is
  correct and mark them as `exiting` to prevent them from being used.
  """

  import Ecto.Changeset, only: [change: 2, get_field: 2]
  import Ecto.Query

  alias Engine.DB.Output
  alias Engine.DB.Transaction

  @type event() :: %{
          eth_height: non_neg_integer,
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

  defp do_callback(multi, [event | tail]), do: multi |> mark_piggybacked_output(event) |> do_callback(tail)
  defp do_callback(multi, []), do: Engine.Repo.transaction(multi)

  # A `txhash` isn't unique, so we just kinda take the `txhash` as a short-hand
  # to figure out which `txhash` it could possibly be with the given `oindex`.
  #
  # See: https://github.com/omisego/elixir-omg/blob/master/apps/omg/lib/omg/state/utxo_set.ex#L81
  defp mark_piggybacked_output(multi, %{output_index: oindex, tx_hash: txhash}) do
    transaction =
      Transaction.find_by_txhash(txhash)
      |> Engine.Repo.one()
      |> Engine.Repo.preload(:outputs)

    case transaction do
      nil ->
        multi

      %Transaction{outputs: outputs} ->
        case Enum.at(outputs, oindex) do
          nil ->
            multi

          output ->
            changeset = outputs |> Enum.at(oindex) |> change(state: "piggybacked")
            position = get_field(changeset, :position)
            Ecto.Multi.update(multi, "piggyback-output-#{position}", changeset)
        end
    end
  end
end
