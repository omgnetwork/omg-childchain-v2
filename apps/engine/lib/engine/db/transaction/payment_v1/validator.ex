defmodule Engine.DB.Transaction.PaymentV1.Validator do
  @moduledoc """
  Handles statefull validation for transaction type "PaymentV1" (1).

  See validate/3 for more details.
  """

  @behaviour Engine.DB.Transaction.Validator

  import Ecto.Changeset, only: [get_field: 2, add_error: 3, put_assoc: 3]

  alias Engine.DB.Transaction.PaymentV1.Type
  alias Engine.DB.Transaction.PaymentV1.Validator.Amount
  alias Engine.DB.Transaction.PaymentV1.Validator.Merge
  alias Engine.DB.Transaction.PaymentV1.Validator.Witness
  alias Engine.DB.TransactionFee
  alias Engine.Fee.FeeClaim
  alias ExPlasma.Output

  @error_messages [
    amounts_do_not_add_up: "Output amounts are greater than input amounts",
    fees_not_covered: "Fees are not covered by inputs",
    fee_token_not_accepted: "Fee token is not accepted",
    overpaying_fees: "Overpaying fees",
    unauthorized_spend: "Given signatures do not match the inputs owners",
    missing_signature: "Not enough signatures for the number of inputs",
    superfluous_signature: "Too many signatures for the number of inputs"
  ]

  @doc """
  Statefully validates a PaymentV1 transaction changeset.
  Note that the fee can be overriden if the transaction is a merge, in this case
  :no_fees_required will be passed to the Amount validator.

  Returns changeset with associated transaction fees if the transaction is valid, or `{:error, {field, error}}` otherwise.
  `paid_fees` is a map indicating how much fees the transaction paid in each currency.
  """
  @spec validate(Ecto.Changeset.t(), Type.accepted_fees_t()) :: Ecto.Changeset.t()
  @impl Engine.DB.Transaction.Validator
  def validate(changeset, fees) do
    input_data = get_decoded_output_data(changeset, :inputs)
    output_data = get_decoded_output_data(changeset, :outputs)
    fees_by_currency = FeeClaim.paid_fees(input_data, output_data)
    witnesses = get_field(changeset, :witnesses)

    with :ok <- Witness.validate(input_data, witnesses),
         fees <- validate_merge_fees(fees, input_data, output_data),
         :ok <- Amount.validate(fees, fees_by_currency) do
      associate_transaction_fees(changeset, fees_by_currency)
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
      |> Output.decode!()
      |> Map.get(:output_data)
    end)
  end

  defp validate_merge_fees(fees, input_data, output_data) do
    case Merge.is_merge?(input_data, output_data) do
      true -> :no_fees_required
      false -> fees
    end
  end

  defp associate_transaction_fees(changeset, fees_by_currency) do
    fees =
      Enum.map(fees_by_currency, fn {currency, amount} ->
        TransactionFee.changeset(%TransactionFee{}, %{currency: currency, amount: amount})
      end)

    put_assoc(changeset, :fees, fees)
  end
end
