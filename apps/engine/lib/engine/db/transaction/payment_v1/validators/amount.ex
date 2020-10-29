defmodule Engine.DB.Transaction.PaymentV1.Validator.Amount do
  @moduledoc """
  Contains validation logic for amounts, see validate/3 for more details.
  """

  alias Engine.DB.Transaction.PaymentV1.Type

  @type validation_result_t() ::
          :ok
          | {:error, {:inputs, :amounts_do_not_add_up}}
          | {:error, {:inputs, :fees_not_covered}}
          | {:error, {:inputs, :fee_token_not_accepted}}
          | {:error, {:inputs, :overpaying_fees}}

  @doc """
  Validates that the amount per token given in the inputs and outputs is correct.
  The following (per token) should be true: input_amount - output_amount - fees = 0
  However fees can only be paid in 1 token per transaction.
  So if we have multiple tokens in a transaction, only one pay the fees and for the rest
  input_amount - output_amount must be 0.

  The logic here is:
  - We group inputs and outputs by token
  - We substract output amounts from input amounts per token
  - We remove tokens that have a 0 amount from the result
  - We ensure that amounts are positive
  - Only token/amount left should be the one that will pay the fee
  - If no token/amount left then it must be a merge or an error
  - We finally match the amount with the given fees

  Returns
  - `:ok` if the amounts are valid,
  or returns:
  - `{:error, {:inputs, :amounts_do_not_add_up}}` if output amounts are greater than input amounts
  - `{:error, {:inputs, :fees_not_covered}}` if fees are not covered by inputs
  - `{:error, {:inputs, :fee_token_not_accepted}}` if the given fee token is not supported
  - `{:error, {:inputs, :overpaying_fees}}` if fees are being overpaid.

  ## Example:

  iex> Engine.DB.Transaction.PaymentV1.Validator.Amount.validate(
  ...> %{<<1::160>> => [1, 3]},
  ...> %{<<1::160>> => 1})
  :ok
  """
  @spec validate(Type.optional_accepted_fees_t(), %{required(<<_::160>>) => pos_integer()}) ::
          validation_result_t()
  def validate(fees, paid_fees_by_currency) do
    with :ok <- positive_amounts(paid_fees_by_currency),
         :ok <- no_fees_required(paid_fees_by_currency, fees),
         :ok <- fees_covered(paid_fees_by_currency, fees) do
      :ok
    else
      :no_fees_required -> :ok
      error -> error
    end
  end

  defp positive_amounts(amounts) do
    case Enum.all?(amounts, &(elem(&1, 1) > 0)) do
      true -> :ok
      false -> {:error, {:inputs, :amounts_do_not_add_up}}
    end
  end

  # No fees required for merge transactions
  defp no_fees_required(amounts, :no_fees_required) when map_size(amounts) == 0, do: :no_fees_required
  defp no_fees_required(_, :no_fees_required), do: {:error, {:inputs, :overpaying_fees}}
  defp no_fees_required(_, _), do: :ok

  # If it's not a merge transaction, we should have at least one token to cover the fees
  defp fees_covered(amounts, _fees) when map_size(amounts) == 0 do
    {:error, {:inputs, :fees_not_covered}}
  end

  # We can't have more than 1 token paying for the fees
  defp fees_covered(amounts, _fees) when map_size(amounts) > 1 do
    {:error, {:inputs, :amounts_do_not_add_up}}
  end

  # In this case, we know that we have only one %{token => amount}
  defp fees_covered(amounts, fees) do
    fee_token = amounts |> Map.keys() |> hd()
    fee_paid = amounts[fee_token]

    case Map.get(fees, fee_token) do
      # Paying fees with an unsupported token
      nil -> {:error, {:inputs, :fee_token_not_accepted}}
      accepted_fee_amounts -> exact_fee_amount(fee_paid, accepted_fee_amounts)
    end
  end

  # The current_amount here is the latest accepted fee amount for this token.
  # We may have a buffer period during when we support previous fee amounts to avoid failure
  # of transactions that was created right before a fee update.
  # If the fee_paid is in the list of supported fee we are good, if not we return an error
  # based on the latest supported amount.
  defp exact_fee_amount(fee_paid, [current_amount | _] = accepted_fee_amounts) do
    cond do
      fee_paid in accepted_fee_amounts ->
        :ok

      current_amount > fee_paid ->
        {:error, {:inputs, :fees_not_covered}}

      current_amount < fee_paid ->
        {:error, {:inputs, :overpaying_fees}}
    end
  end
end
