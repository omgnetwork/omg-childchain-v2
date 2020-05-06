defmodule Engine.Feefeed.Fees.Calculator do
  @moduledoc """
  Handles the calculation of fees by dispatching it to different modules
  depending on the type of the fee rule to compute.
  """

  alias Engine.DB.FeeRules
  alias Engine.DB.Fees
  alias Engine.Feefeed.Fees.FlatFeeCalculator

  @calculator_map %{
    "fixed" => FlatFeeCalculator
  }

  @doc """
  Calculate fees for each fee rule by dispatching it to the matching calculator.
  """
  @spec calculate(FeeRules.fee_rule_data_t(), keyword()) ::
          {:ok, Fees.fee_data_t()} | {:error, :unsupported_fee_type, binary()}
  def calculate(fee_rules, opts \\ []) do
    Enum.reduce_while(fee_rules, {:ok, %{}}, fn {transaction_type, rules}, {:ok, fees} ->
      case reduce_for_currency(rules, opts) do
        {:ok, fees_for_type} ->
          {:cont, {:ok, Map.put(fees, transaction_type, fees_for_type)}}

        error ->
          {:halt, error}
      end
    end)
  end

  defp reduce_for_currency(rules, opts) do
    Enum.reduce_while(rules, {:ok, %{}}, fn {currency, %{"type" => type} = currency_rules}, {:ok, fees} ->
      @calculator_map
      |> Map.get(type)
      |> calculate(currency_rules, opts)
      |> case do
        {:ok, fees_for_currency} ->
          {:cont, {:ok, Map.put(fees, currency, fees_for_currency)}}

        {:error, :unsupported_fee_type} = error ->
          {:halt, Tuple.append(error, "got: '#{type}', which is not currently supported")}

        error ->
          {:halt, error}
      end
    end)
  end

  defp calculate(nil, _rules, _opts), do: {:error, :unsupported_fee_type}
  defp calculate(calculator, rules, opts), do: calculator.calculate(rules, opts)
end
