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

  alias Engine.DB.Transaction

  @type t() :: %{
          creating_transaction: Transaction.t(),
          creating_transaction_id: pos_integer(),
          id: pos_integer(),
          inserted_at: DateTime.t(),
          output_data: binary() | nil,
          output_id: binary() | nil,
          output_type: pos_integer(),
          position: pos_integer() | nil,
          spending_transaction: Transaction.t() | nil,
          spending_transaction_id: pos_integer() | nil,
          state: String.t(),
          updated_at: DateTime.t()
        }

  @timestamps_opts [inserted_at: :node_inserted_at, updated_at: :node_updated_at]

  schema "outputs" do
    # Extracted from `output_id`
    field(:position, :integer)

    field(:output_type, :integer)
    field(:output_data, :binary)
    field(:output_id, :binary)

    field(:state, :string, default: "pending")

    belongs_to(:spending_transaction, Engine.DB.Transaction)
    belongs_to(:creating_transaction, Engine.DB.Transaction)

    field(:inserted_at, :utc_datetime)
    field(:updated_at, :utc_datetime)

    timestamps()
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

  @doc """
  Query to return all usable outputs.
  """
  def usable() do
    from(o in __MODULE__,
      where: is_nil(o.spending_transaction_id) and o.state == "confirmed"
    )
  end

  # Extract the position from the output id and store it on the table.
  # Used by the Transaction to find outputs quickly.
  defp extract_position(changeset, %{output_id: %{position: position}}) do
    put_change(changeset, :position, position)
  end

  defp extract_position(changeset, _), do: put_change(changeset, :position, nil)

  # Doing this hacky work around so we don't need to convert to/from binary to hex string for the json column.
  # Instead, we re-encoded as rlp encoded items per specification. This helps us future proof it a bit because
  # we don't necessarily know what the future output data looks like yet. If there's data we need, we can
  # at a later time pull them out and turn them into columns.
  defp encode_output_data(changeset, params) do
    case Map.get(params, :output_data) do
      nil ->
        changeset

      _output_data ->
        {:ok, output_data} =
          %ExPlasma.Output{}
          |> struct(params)
          |> ExPlasma.Output.encode()

        put_change(changeset, :output_data, output_data)
    end
  end

  defp encode_output_id(changeset, params) do
    case Map.get(params, :output_id) do
      nil ->
        changeset

      _output_id ->
        {:ok, output_id} =
          %ExPlasma.Output{}
          |> struct(params)
          |> ExPlasma.Output.encode(as: :input)

        put_change(changeset, :output_id, output_id)
    end
  end
end
