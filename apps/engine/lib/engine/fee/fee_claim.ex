defmodule Engine.Fee.FeeClaim do
  @moduledoc """
  Contains logic related to fee claiming.
  """

  alias Engine.DB.Transaction.PaymentV1.Type

  @type paid_fees_t() :: %{required(<<_::160>>) => pos_integer()}

  @doc """
  Calculates and returns a map of fee paid given input and output data.
  This correspond to the sum of input amounts - output amounts for each token,
  the result is a map of %{token => amount}.
  Only returns tokens that have a positive amount of fees paid.
  """
  @spec paid_fees(Type.output_list_t(), Type.output_list_t()) :: paid_fees_t()
  def paid_fees(input_data, output_data) do
    output_amounts = reduce_amounts(output_data)

    input_data
    |> reduce_amounts()
    |> substract_outputs_from_inputs(output_amounts)
    |> filter_zero_amounts()
  end

  defp reduce_amounts(output_data) do
    Enum.reduce(output_data, %{}, fn data, acc ->
      amount = Map.get(acc, data.token, 0) + data.amount
      Map.put(acc, data.token, amount)
    end)
  end

  defp substract_outputs_from_inputs(input_amounts, output_amounts) do
    Map.merge(input_amounts, output_amounts, fn _token, input_amount, output_amount -> input_amount - output_amount end)
  end

  defp filter_zero_amounts(amounts) do
    amounts
    |> Enum.filter(fn {_token, amount} -> amount != 0 end)
    |> Map.new()
  end
end
