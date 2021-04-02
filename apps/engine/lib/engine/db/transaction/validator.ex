defmodule Engine.DB.Transaction.Validator do
  @moduledoc """
  Contains all kind of validation for transactions.
  This module should be used to validate transactions before
  their insertion in the DB.
  """

  import Ecto.Changeset, only: [get_field: 2, add_error: 3, put_assoc: 3]

  alias Engine.DB.Output
  alias Engine.Repo

  @type_validators %{
    1 => Engine.DB.Transaction.PaymentV1.Validator
  }

  @type accepted_fee_t() :: %{required(<<_::160>>) => list(pos_integer())}

  @callback validate(Ecto.Changeset.t(), accepted_fee_t()) :: Ecto.Changeset.t()

  @doc """
  Validate the transaction bytes with the generic transaction format protocol.
  See ExPlasma.Transaction.validate/1.

  Returns the changeset unchanged if valid or with an error otherwise.
  """
  @spec validate_protocol(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def validate_protocol(changeset) do
    changeset
    |> get_field(:signed_tx)
    |> ExPlasma.validate()
    |> process_protocol_validation_results(changeset)
  end

  @doc """
  Validates that the given input positions are correct. To create a transaction with inputs:
    * The position for the input must exist.
    * The position for the input must not have been spent.

  If so, loads and associates the records to this transaction keeping the order and setting their state to :spent.

  Returns the changeset with associated input or an error.
  """
  @spec associate_inputs(Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def associate_inputs(changeset, params) do
    given_input_positions = Enum.map(params.inputs, & &1.output_id.position)
    usable_inputs = given_input_positions |> Output.OutputQuery.usable_for_positions() |> Repo.all()
    usable_input_positions = Enum.map(usable_inputs, & &1.position)

    case given_input_positions -- usable_input_positions do
      [] ->
        ordered_spent_inputs =
          Enum.map(given_input_positions, fn given_input_position ->
            usable_inputs
            |> Enum.find(&(&1.position == given_input_position))
            |> Output.spend()
          end)

        put_assoc(changeset, :inputs, ordered_spent_inputs)

      missing_inputs ->
        add_error(changeset, :inputs, "inputs #{inspect(missing_inputs)} are missing, spent, or not yet available")
    end
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

  def validate_statefully(changeset, params) do
    get_validator(params.tx_type).validate(changeset, params.fees)
  end

  # Private
  defp process_protocol_validation_results(:ok, changeset), do: changeset

  defp process_protocol_validation_results({:error, {field, message}}, changeset) do
    formatted_message = message |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
    add_error(changeset, field, formatted_message)
  end

  defp get_validator(type), do: Map.fetch!(@type_validators, type)
end
