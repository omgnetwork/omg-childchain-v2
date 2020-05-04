defmodule Engine.DB.Output do
  @moduledoc """
  Ecto schema for Outputs in the system. The Output can exist in two forms:

  * Being built, as a new unspent output (Output). Since the blocks have not been formed, the full output position
  information does not exist for the given Output. We only really know the oindex at this point.

  * Being formed into a block via the transaction. At this point we should have all the information available to
  create a full Output position for this.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  schema "outputs" do
    # Extracted from `output_id`
    field(:position, :integer)

    field(:output_type, :integer)
    field(:output_data, :binary)
    field(:output_id, :binary)

    field(:state, :string, default: "pending")

    belongs_to(:spending_transaction, Engine.DB.Transaction)
    belongs_to(:creating_transaction, Engine.DB.Transaction)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Default changset. Generates the Output and ensures
  that it meets the state-less validations.
  """
  def changeset(struct, params) do
    struct
    |> cast(params, [:state, :output_type])
    |> extract_position(params)
    |> encode_output_data(params)
    |> encode_output_id(params)
  end

  # Extract the position from the output id and store it on the table.
  # Used by the Transaction to find outputs quickly.
  defp extract_position(changeset, %{output_id: id}) do
    position = Map.get(id || %{}, :position)
    put_change(changeset, :position, position)
  end

  # Doing this hacky work around so we don't need to convert to/from binary to hex string for the json column.
  # Instead, we re-encoded as rlp encoded items per specification. This helps us future proof it a bit because
  # we don't necessarily know what the future output data looks like yet. If there's data we need, we can
  # at a later time pull them out and turn them into columns.
  defp encode_output_data(changeset, params) do
    case Map.get(params, :output_data) do
      nil ->
        changeset

      _output_data ->
        output = struct(%ExPlasma.Output{}, params)
        put_change(changeset, :output_data, ExPlasma.Output.encode(output))
    end
  end

  defp encode_output_id(changeset, params) do
    case Map.get(params, :output_id) do
      nil ->
        changeset

      _output_id ->
        output = struct(%ExPlasma.Output{}, params)
        put_change(changeset, :output_id, ExPlasma.Output.encode(output, as: :input))
    end
  end

  @doc """
  Query to return all usable outputs.
  """
  def usable() do
    from(o in __MODULE__,
      where: is_nil(o.spending_transaction_id) and o.state == "confirmed"
    )
  end
end
