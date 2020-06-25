defmodule Engine.DB.Transaction.PaymentV1.Validator do
  @moduledoc """
  Handles statefull validation for transaction type "PaymentV1" (1) and kind :transfer.

  See validate/3 for more details.
  """

  @behaviour Engine.DB.Transaction.Validator

  import Ecto.Changeset, only: [get_field: 2, add_error: 3]

  alias Engine.DB.Transaction.PaymentV1.Type
  alias Engine.DB.Transaction.PaymentV1.Validator.Amount, as: AmountValidator
  alias Engine.DB.Transaction.PaymentV1.Validator.Merge, as: MergeValidator
  alias Engine.DB.Transaction.PaymentV1.Validator.Witness, as: WitnessValidator

  @error_messages [
    amounts_do_not_add_up: "output amounts are greater than input amounts",
    fees_not_covered: "fees are not covered by inputs",
    fee_token_not_accepted: "fee token is not accepted",
    overpaying_fees: "overpaying fees",
    unauthorized_spend: "given signatures do not match the inputs owners",
    missing_signature: "not enough signatures for the number of inputs",
    superfluous_signature: "too many signatures for the number of inputs"
  ]

  @doc """
  Statefully validates a PaymentV1 transaction changeset.
  Note that the fee can be overriden if the transaction is a merge, in this case
  :no_fees_required will be passed to the AmountValidator.

  Returns `:ok` if the transaction is valid, or `{:error, {field, error}}` otherwise.
  """
  @spec validate(Ecto.Changeset.t(), Type.accepted_fees_t()) :: Ecto.Changeset.t()
  @impl Engine.DB.Transaction.Validator
  def validate(changeset, fees) do
    input_data = get_decoded_output_data(changeset, :inputs)
    output_data = get_decoded_output_data(changeset, :outputs)
    witnesses = get_field(changeset, :witnesses)

    with :ok <- WitnessValidator.validate(input_data, witnesses),
         fees <- validate_merge_fees(fees, input_data, output_data),
         :ok <- AmountValidator.validate(fees, input_data, output_data) do
      changeset
    else
      {:error, {field, message}} ->
        add_error(changeset, field, @error_messages[message])
    end
  end

  defp get_decoded_output_data(changeset, type) do
    changeset
    |> get_field(type)
    |> Enum.map(fn output ->
      output.output_data
      |> ExPlasma.Output.decode()
      |> Map.get(:output_data)
    end)
  end

  defp validate_merge_fees(fees, input_data, output_data) do
    case MergeValidator.is_merge?(input_data, output_data) do
      true -> :no_fees_required
      false -> fees
    end
  end
end
