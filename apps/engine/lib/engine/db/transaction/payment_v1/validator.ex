defmodule Engine.DB.Transaction.PaymentV1.Validator do
  @moduledoc """
  Handles statefull validation for transaction type "PaymentV1" (1) and kind :transfer.

  See validate/3 for more details.
  """

  @behaviour Engine.DB.Transaction.Validator

  alias Engine.DB.Transaction.PaymentV1.AmountValidator
  alias Engine.DB.Transaction.PaymentV1.MergeValidator
  alias Engine.DB.Transaction.PaymentV1.WitnessValidator
  alias Engine.DB.Transaction.PaymentV1.Type

  @doc """
  Statefully validates inputs and outputs of a transaction given a fee.
  Note that the fee can be overriden if the transaction is a merge, in this case
  :no_fees_required will be passed to the AmountValidator.

  For a deeper explanation of the validation logic, see `AmountValidator/validate/2`

  Returns `:ok` if the transaction is valid, or `{:error, {field, error}}` otherwise.

  ## Example:

  iex> Engine.DB.Transaction.PaymentV1.Validator.validate([
  ...> %{output_guard: <<1::160>>, token: <<1::160>>, amount: 1 },
  ...> %{output_guard: <<1::160>>, token: <<2::160>>, amount: 2}], [
  ...> %{output_guard: <<2::160>>, token: <<2::160>>, amount: 2}],
  ...> [<<1::160>>, <<1::160>>],
  ...> %{<<1::160>> => [1, 3]})
  :ok
  """
  @spec validate(Type.output_list_t(), Type.output_list_t(), list(ExPlasma.Crypto.address_t()), Type.accepted_fees_t()) ::
          Type.validation_result_t()
  @impl Engine.DB.Transaction.Validator
  def validate(input_data, output_data, witnesses, fees) do
    with :ok <- WitnessValidator.validate(input_data, witnesses),
         fees <- validate_merge_fees(fees, input_data, output_data),
         :ok <- AmountValidator.validate(fees, input_data, output_data) do
      :ok
    end
  end

  defp validate_merge_fees(fees, input_data, output_data) do
    case MergeValidator.is_merge?(input_data, output_data) do
      true -> :no_fees_required
      false -> fees
    end
  end
end
