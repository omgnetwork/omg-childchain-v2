defmodule Engine.Fee.FeeClaim do
  @moduledoc """
  Contains logic related to fee claiming.
  """

  alias Engine.DB.Transaction.PaymentV1.Type
  alias ExPlasma.Builder
  alias ExPlasma.Transaction, as: ExPlasmaTx
  alias ExPlasma.Transaction.Type.Fee, as: ExPlasmaFee

  @type paid_fees_t() :: %{required(<<_::160>>) => pos_integer()}

  @doc """
  Calculates and returns a map of fee paid given input and output data.
  This correspond to the sum of input amounts - output amounts for each token,
  the result is a map of %{token => amount}.
  Only returns tokens that have a positive amount of fees paid.
  """
  @spec fee_paid(Type.output_list_t(), Type.output_list_t()) :: %{required(<<_::160>>) => pos_integer()}
  def fee_paid(input_data, output_data) do
    output_amounts = reduce_amounts(output_data)

    input_data
    |> reduce_amounts()
    |> substract_outputs_from_inputs(output_amounts)
    |> filter_zero_amounts()
  end

  @doc """
  Generates a list of fee transactions for the given block.
  The given block is expected to have its transaction inputs and outputs preloaded.
  - Takes the inputs and outputs of all transactions in the block and substracts amounts to get the fees paid for each transactions.
  - Creates a fee transaction for each fee token found
  Returns the list of binary encoded transactions.
  """
  @spec generate_fee_transactions(pos_integer(), paid_fees_t(), <<_::160>>) :: list(binary())
  def generate_fee_transactions(blknum, fees_by_currency, fee_claimer) do
    Enum.map(fees_by_currency, fn {token, amount} -> build_fee_transaction(blknum, fee_claimer, token, amount) end)
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

  defp build_fee_transaction(blknum, owner, token, amount) do
    output = ExPlasmaFee.new_output(owner, token, amount)

    {:ok, fee_tx} =
      ExPlasma.fee()
      |> Builder.new(outputs: [output])
      |> ExPlasmaTx.with_nonce(%{blknum: blknum, token: token})

    ExPlasma.encode!(fee_tx, signed: true)
  end
end
