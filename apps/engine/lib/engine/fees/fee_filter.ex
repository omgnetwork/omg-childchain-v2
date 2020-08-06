defmodule Engine.Fees.FeeFilter do
  @moduledoc """
  Filtering of fees.
  """

  alias Engine.Fees

  @doc ~S"""
  Returns a filtered map of fees given a list of transaction types and currencies.
  Passing a nil value or an empty array skip the filtering.

  ## Examples

      iex> Engine.Fees.FeeFilter.filter(
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
      ...>     },
      ...>     2 => %{
      ...>       "omg" => %{
      ...>         amount: 3,
      ...>         subunit_to_unit: 1_000_000_000_000_000_000,
      ...>         pegged_amount: 4,
      ...>         pegged_currency: "USD",
      ...>         pegged_subunit_to_unit: 100,
      ...>         updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
      ...>       }
      ...>     },
      ...>     3 => %{
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
      ...>   [1,2],
      ...>   ["eth"]
      ...> )
      {:ok,
        %{
          1 => %{
            "eth" => %{
              amount: 1,
              subunit_to_unit: 1_000_000_000_000_000_000,
              pegged_amount: 4,
              pegged_currency: "USD",
              pegged_subunit_to_unit: 100,
              updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
            }
          },
          2 => %{}
        }
      }

  """
  @spec filter(Fees.full_fee_t(), list(non_neg_integer()), list(String.t()) | nil) ::
          {:ok, Fees.full_fee_t()} | {:error, :currency_fee_not_supported} | {:error, :tx_type_not_supported}
  # empty list = no filter
  def filter(fees, []), do: {:ok, fees}
  def filter(fees, nil), do: {:ok, fees}

  def filter(fees, tx_types, currencies) do
    case filter_tx_type(fees, tx_types) do
      {:ok, fees} ->
        filter_currency(fees, currencies)

      error ->
        error
    end
  end

  defp filter_tx_type(fees, []), do: {:ok, fees}
  defp filter_tx_type(fees, nil), do: {:ok, fees}

  defp filter_tx_type(fees, tx_types) do
    case validate_tx_types(tx_types, fees) do
      :ok ->
        {:ok, Map.take(fees, tx_types)}

      error ->
        error
    end
  end

  defp validate_tx_types(tx_types, fees) do
    tx_types
    |> Enum.all?(&Map.has_key?(fees, &1))
    |> case do
      true -> :ok
      false -> {:error, :tx_type_not_supported}
    end
  end

  defp filter_currency(fees, []), do: {:ok, fees}
  defp filter_currency(fees, nil), do: {:ok, fees}

  defp filter_currency(fees, currencies) do
    case validate_currencies(currencies, fees) do
      :ok ->
        {:ok, do_filter_currencies(currencies, fees)}

      error ->
        error
    end
  end

  defp validate_currencies(currencies, fees) do
    currencies
    |> Enum.all?(fn currency -> Enum.any?(fees, &Map.has_key?(elem(&1, 1), currency)) end)
    |> case do
      true -> :ok
      false -> {:error, :currency_fee_not_supported}
    end
  end

  defp do_filter_currencies(currencies, fees) do
    fees
    |> Enum.map(fn {tx_type, fees_for_tx_type} ->
      {tx_type, Map.take(fees_for_tx_type, currencies)}
    end)
    |> Enum.into(%{})
  end
end
