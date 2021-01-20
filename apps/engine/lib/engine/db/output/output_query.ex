defmodule Engine.DB.Output.OutputQuery do
  @moduledoc """
  Queries related to outputs
  """

  import Ecto.Query, only: [from: 2]

  alias Engine.DB.Output

  @doc """
  Return all `:confirmed` outputs without a spending transaction that have the given positions.
  """
  def usable_for_positions(positions) do
    Output |> usable() |> by_position(positions)
  end

  # enabled transaction chaining would allow the state to also be pending!
  # what needs to be done to avoid `o.state == ^:pending` is to
  # mark all pending outputs to confirmed after their origin block gets mined (or submitted to contracts)
  defp usable(query) do
    from(o in query,
      where: (is_nil(o.spending_transaction_id) and o.state == ^:confirmed) or o.state == ^:pending
    )
  end

  defp by_position(query, positions) do
    from(o in query,
      where: o.position in ^positions
    )
  end
end
