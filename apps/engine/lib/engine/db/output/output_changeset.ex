defmodule Engine.DB.Output.OutputChangeset do
  @moduledoc """
  Contains changesets related to outputs
  """

  import Ecto.Changeset

  alias Engine.DB.Output

  @doc """
  Changeset for deposits.
  This updates:
  - position
  - output_id
  - output_data
  - output_type
  - state (should be :confirmed)
  """
  def deposit(output, params) do
    output
    |> state(params)
    |> input_position(params)
    |> output_data(params)
  end

  @doc """
  Changeset for new outputs (created by transactions).
  This updates:
  - output_data
  - output_type
  - state (should be :pending)
  """
  def new(output, params) do
    output
    |> state(params)
    |> output_data(params)
  end

  @doc """
  Changeset for output state change.
  This updates:
  - state (should be :pending)
  """
  def state(output, params) do
    output
    |> cast(params, [:state])
    |> validate_required([:state])
    |> validate_inclusion(:state, Output.states())
  end

  defp output_data(output, params) do
    output
    |> cast(params, [:output_type])
    |> put_output_data(params)
    |> validate_required([:output_type, :output_data])
  end

  defp input_position(output, params) do
    output
    |> put_position(params)
    |> put_output_id(params)
    |> validate_required([:output_id, :position])
  end

  # Extract the position from the output id and store it on the table.
  # Used by the Transaction to find outputs quickly.
  defp put_position(changeset, %{output_id: %{position: position}}) do
    put_change(changeset, :position, position)
  end

  defp put_position(changeset, _), do: changeset

  # Doing this hacky work around so we don't need to convert to/from binary to hex string for the json column.
  # Instead, we re-encoded as rlp encoded items per specification. This helps us future proof it a bit because
  # we don't necessarily know what the future output data looks like yet. If there's data we need, we can
  # at a later time pull them out and turn them into columns.
  defp put_output_data(changeset, %{output_data: nil}), do: changeset

  defp put_output_data(changeset, params) do
    {:ok, output_data} =
      %ExPlasma.Output{}
      |> struct(params)
      |> ExPlasma.Output.encode()

    put_change(changeset, :output_data, output_data)
  end

  defp put_output_id(changeset, %{output_id: nil}), do: changeset

  defp put_output_id(changeset, params) do
    {:ok, output_id} =
      %ExPlasma.Output{}
      |> struct(params)
      |> ExPlasma.Output.encode(as: :input)

    put_change(changeset, :output_id, output_id)
  end
end
