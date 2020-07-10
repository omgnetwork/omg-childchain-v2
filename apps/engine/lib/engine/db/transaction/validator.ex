defmodule Engine.DB.Transaction.Validator do
  @moduledoc """
  Contains all kind of validation for transactions.
  This module should be used to validate transactions before
  their insertion in the DB.
  """

  import Ecto.Changeset, only: [get_field: 2, add_error: 3, put_change: 3]
  import Ecto.Query, only: [where: 3]

  alias Engine.DB.Output
  alias Engine.DB.Transaction.PaymentV1
  alias Engine.Repo

  @error_messages [
    cannot_be_zero: "can not be zero",
    exceeds_maximum: "can not exceed maximum value"
  ]

  @type_validators %{
    1 => PaymentV1.Validator
  }

  @type accepted_fee_t() :: %{required(<<_::160>>) => list(pos_integer())}

  @callback validate(Ecto.Changeset.t(), accepted_fee_t()) :: Ecto.Changeset.t()

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
        sorted_usable_inputs =
          Enum.map(given_input_positions, fn given_input_position ->
            Enum.find(usable_inputs, &(&1.position == given_input_position))
          end)

        put_change(changeset, :inputs, sorted_usable_inputs)

      missing_inputs ->
        add_error(changeset, :inputs, "inputs #{inspect(missing_inputs)} are missing, spent, or not yet available")
    end
  end

  @doc """
  Attempts to recover witnesses (addresses) from the given signatures.
  Maps the list of witnesses to the `:witnesses` key in the changeset if valid,
  or adds an error to changeset otherwise.
  """

  # @spec validate_signatures(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  # def validate_signatures(changeset) do
  #   changeset
  #   |> get_field(:raw_tx)
  #   |> ExPlasma.Transaction.recover_signatures()
  #   |> process_signatures_validation_results(changeset)
  # end

  @doc """
  Validate the transaction bytes with the generic transaction format protocol.
  See ExPlasma.Transaction.validate/1.

  Returns the changeset unchanged if valid or with an error otherwise.
  """
  @spec validate_protocol(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def validate_protocol(changeset) do
    changeset
    |> get_field(:signed_tx)
    |> ExPlasma.Transaction.validate()
    |> process_protocol_validation_results(changeset)
  end

  @doc """
  Validates the transaction taking into account its state and output/input data.
  This will dispatch the validation depending on the transaction type.
  Refer to @type_validators for the list of validators per transaction type.

  Note: Will return the changeset unchanged and NOT perform validation if
  there is already an error in the changeset.

  Returns the changeset unchanged if valid or with an error otherwise.
  """
  @spec validate_statefully(Ecto.Changeset.t(), map()) :: Ecto.Changeset.t() | no_return()
  # We can't perform statefull validation if there are errors in the changeset
  def validate_statefully(%Ecto.Changeset{valid?: false} = changeset, _params), do: changeset

  # Deposit don't need to be validated as we're building them internally from contract events
  def validate_statefully(changeset, %{kind: :deposit}), do: changeset

  def validate_statefully(changeset, %{tx_type: tx_type, fees: fees}) do
    get_validator(tx_type).validate(changeset, fees)
  end

  # Private
  defp process_signatures_validation_results({:ok, addresses}, changeset) do
    put_change(changeset, :witnesses, addresses)
  end

  defp process_signatures_validation_results({:error, error}, changeset) do
    add_error(changeset, :witnesses, "invalid signature: #{inspect(error)}")
  end

  defp get_input_positions(changeset) do
    changeset |> get_field(:inputs) |> Enum.map(&Map.get(&1, :position))
  end

  # Return all confirmed outputs that have the given positions.
  defp usable_outputs_for(positions) do
    where(Output.usable(), [output], output.position in ^positions)
  end

  defp process_protocol_validation_results({:ok, _}, changeset), do: changeset

  defp process_protocol_validation_results({:error, {field, message}}, changeset) do
    add_error(changeset, field, @error_messages[message])
  end

  defp get_validator(type), do: Map.fetch!(@type_validators, type)
end
