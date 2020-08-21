defmodule Engine.Fees.Fetcher.Updater.Merger do
  @moduledoc """
  Handles the parsing, formatting and merging of previous and current fees
  """

  alias Engine.Fees

  @doc """
  Merges a current and previous server fee specs into a formatted map

  ## Examples

      iex> Engine.Fees.Fetcher.Updater.Merger.merge_specs(
      ...>   %{
      ...>     1 => %{
      ...>       "eth" => %{
      ...>         amount: 1,
      ...>         subunit_to_unit: 1_000_000_000_000_000_000,
      ...>         pegged_amount: 4,
      ...>         pegged_currency: "USD",
      ...>         pegged_subunit_to_unit: 100,
      ...>         updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
      ...>       },
      ...>       "omg" => %{
      ...>         amount: 3,
      ...>         subunit_to_unit: 1_000_000_000_000_000_000,
      ...>         pegged_amount: 4,
      ...>         pegged_currency: "USD",
      ...>         pegged_subunit_to_unit: 100,
      ...>         updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
      ...>       }
      ...>     }
      ...>   },
      ...>   %{
      ...>     1 => %{
      ...>       "eth" => %{
      ...>         amount: 2,
      ...>         subunit_to_unit: 1_000_000_000_000_000_000,
      ...>         pegged_amount: 4,
      ...>         pegged_currency: "USD",
      ...>         pegged_subunit_to_unit: 100,
      ...>         updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
      ...>       }
      ...>     }
      ...>   }
      ...> )
      %{
        1 => %{
          "eth" => [1, 2],
          "omg" => [3]
        }
      }

  """
  @spec merge_specs(Fees.full_fee_t(), Fees.full_fee_t() | nil) :: Fees.typed_merged_fee_t()
  def merge_specs(current_specs, nil), do: remove_unused_fields(current_specs)

  def merge_specs(current_specs, previous_specs) do
    with current_specs <- remove_unused_fields(current_specs),
         previous_specs <- remove_unused_fields(previous_specs) do
      Map.merge(current_specs, previous_specs, &resolve_merge_conflict_for_type/3)
    end
  end

  defp resolve_merge_conflict_for_type(_type, current_specs, previous_specs) do
    Map.merge(current_specs, previous_specs, &resolve_merge_conflict_for_currency/3)
  end

  defp resolve_merge_conflict_for_currency(_currency, [amount], [amount]), do: [amount]

  defp resolve_merge_conflict_for_currency(_currency, [current_amount], [previous_amount]) do
    [current_amount, previous_amount]
  end

  defp remove_unused_fields(nil), do: nil

  defp remove_unused_fields(fee_specs) do
    fee_specs
    |> Enum.map(&parse_for_type/1)
    |> Enum.into(%{})
  end

  defp parse_for_type(params) do
    {type, specs} = params

    updated_spec =
      specs
      |> Enum.map(&parse_for_currency/1)
      |> Enum.into(%{})

    {type, updated_spec}
  end

  defp parse_for_currency(params) do
    {currency, %{amount: amount}} = params

    {currency, [amount]}
  end
end
