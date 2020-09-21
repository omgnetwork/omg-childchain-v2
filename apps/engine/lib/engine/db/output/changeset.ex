defmodule Engine.DB.Output.Changeset do
  @moduledoc """
  """

  import Ecto.Changeset

  alias Engine.DB.Output

  def deposit_changeset(struct, params) do
    struct
    |> state_changeset(params)
    |> input_position_changeset(params)
    |> output_data_changeset(params)
  end

  def new_changeset(struct, params) do
    struct
    |> state_changeset(params)
    |> output_data_changeset(params)
  end

  def state_changeset(output, params) do
    output
    |> cast(params, [:state])
    |> validate_required([:state])
    |> validate_inclusion(:state, Output.states())
  end

  def output_data_changeset(struct, params) do
    struct
    |> cast(params, [:output_type])
    |> encode_output_data(params)
    |> validate_required([:output_type, :output_data])
  end

  def input_position_changeset(struct, params) do
    struct
    |> extract_position(params)
    |> encode_output_id(params)
    |> validate_required([:output_id, :position])
  end

  # Extract the position from the output id and store it on the table.
  # Used by the Transaction to find outputs quickly.
  defp extract_position(changeset, %{output_id: %{position: position}}) do
    put_change(changeset, :position, position)
  end

  defp extract_position(changeset, _), do: changeset

  # Doing this hacky work around so we don't need to convert to/from binary to hex string for the json column.
  # Instead, we re-encoded as rlp encoded items per specification. This helps us future proof it a bit because
  # we don't necessarily know what the future output data looks like yet. If there's data we need, we can
  # at a later time pull them out and turn them into columns.
  defp encode_output_data(changeset, %{output_data: nil}), do: changeset

  defp encode_output_data(changeset, params) do
    {:ok, output_data} =
      %ExPlasma.Output{}
      |> struct(params)
      |> ExPlasma.Output.encode()

    put_change(changeset, :output_data, output_data)
  end

  defp encode_output_id(changeset, %{output_id: nil}), do: changeset

  defp encode_output_id(changeset, params) do
    {:ok, output_id} =
      %ExPlasma.Output{}
      |> struct(params)
      |> ExPlasma.Output.encode(as: :input)

    put_change(changeset, :output_id, output_id)
  end
end
