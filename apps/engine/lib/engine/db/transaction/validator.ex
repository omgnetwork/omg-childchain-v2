defmodule Engine.DB.Transaction.Validator do
  @moduledoc """
  """

  import Ecto.Changeset, only: [get_field: 2, add_error: 3, put_change: 3]
  import Ecto.Query, only: [where: 3]

  alias Engine.DB.Output
  alias Engine.Repo
  alias Engine.DB.Transaction.PaymentV1

  @error_messages [
    # Stateless ex_plasma errors
    cannot_be_zero: "can not be zero",
    exceeds_maximum: "can't exceed maximum value",
    # Statefull local errors
    amounts_do_not_add_up: "output amounts are greater than input amounts",
    fees_not_covered: "fees are not covered by inputs",
    fee_token_not_accepted: "fee token is not accepted",
    overpaying_fees: "overpaying fees"
  ]

  @transaction_validators %{
    1 => %{"transfer" => PaymentV1.TransferValidator, "deposit" => PaymentV1.DepositValidator}
  }

  @callback validate(list(map()), list(map()), %{required(<<_::160>>) => list(pos_integer())} | :no_fees_required) ::
              {:ok, map() | nil} | {:error, {atom(), atom()}}

  @doc """
  Validates that the given changesets inputs are correct. To create a transaction with inputs:
    * The position for the input must exist.
    * The position for the input must not have been spent.

  If so, associate the records to this transaction.

  Returns the changeset with associated input or an error.
  """
  @spec validate_inputs(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def validate_inputs(changeset) do
    given_input_positions = get_input_positions(changeset)
    usable_inputs = given_input_positions |> usable_outputs_for() |> Repo.all()
    usable_input_positions = Enum.map(usable_inputs, & &1.position)

    case given_input_positions -- usable_input_positions do
      [] ->
        put_change(changeset, :inputs, usable_inputs)

      missing_inputs ->
        add_error(changeset, :inputs, "inputs #{inspect(missing_inputs)} are missing, spent, or not yet available")
    end
  end

  @doc """
  Validate the transaction bytes with the generic transaction format protocol.
  See ExPlasma.Transaction.validate/1.

  Returns the changeset unchanged or with an error.
  """
  @spec validate_protocol(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def validate_protocol(changeset) do
    changeset
    |> get_field(:tx_bytes)
    |> ExPlasma.decode()
    |> ExPlasma.Transaction.validate()
    |> process_validation_results(changeset)
  end

  @doc """
  Validates the transaction taking into account its state and output/input data.
  This will dispatch the validation depending on the transaction type.
  Refer to @transaction_validators for the list of validator per transaction type.

  Note: Will return the changeset unchanged and NOT perform validation if
  there is already an error in the changeset.

  Returns the changeset unchanged or with an error
  """
  @spec validate_statefully(
          Ecto.Changeset.t(),
          pos_integer(),
          String.t(),
          %{required(<<_::160>>) => list(pos_integer())} | :no_fees_required
        ) :: Ecto.Changeset.t()
  # We can't perform statefull validation if there are errors in the changeset
  def validate_statefully(%Ecto.Changeset{valid?: false} = changeset, _, _, _) do
    changeset
  end

  def validate_statefully(changeset, tx_type, kind, fees) do
    input_data = get_decoded_output_data(changeset, :inputs)
    output_data = get_decoded_output_data(changeset, :outputs)

    input_data
    |> get_validator(tx_type, kind).validate(output_data, fees)
    |> process_validation_results(changeset)
  end

  defp get_input_positions(changeset) do
    changeset |> get_field(:inputs) |> Enum.map(&Map.get(&1, :position))
  end

  # Return all confirmed outputs that have the given positions.
  defp usable_outputs_for(positions) do
    where(Output.usable(), [output], output.position in ^positions)
  end

  defp process_validation_results({:ok, _}, changeset), do: changeset
  defp process_validation_results(:ok, changeset), do: changeset

  defp process_validation_results({:error, {field, message}}, changeset) do
    add_error(changeset, field, @error_messages[message])
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

  defp get_validator(type, kind) do
    type
    |> get_validator_for_type()
    |> Map.fetch!(kind)
  end

  defp get_validator_for_type(type) do
    case Map.fetch(@transaction_validators, type) do
      {:ok, type_validators} ->
        type_validators

      :error ->
        raise ArgumentError, "transaction type #{type} does not exist."
    end
  end
end
