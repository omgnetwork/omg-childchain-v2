defmodule Engine.DB.Output do
  @moduledoc """
  Ecto schema for Outputs in the system. The Output can exist in two forms:

  * Being built, as a new unspent output (Output). Since the blocks have not been formed, the full output position
  information does not exist for the given Output. We only really know the oindex at this point.

  * Being formed into a block via the transaction. At this point we should have all the information available to
  create a full Output position for this.

  The schema contains the following fields:

  - position: The integer posision of the Output. It is calculated as follow:
    block number * block offset (defaults: `1000000000`) + transaction position * transaction offset (defaults to `10000`) + index of the UTXO in the list of outputs of the transaction
  - output_type: The integer representing the output type, ie: `1` for payment v1, `2` for fees.
  - output_data: The binary encoded output data, for payment v1 and fees, this is the RLP encoded binary of the output type, owner, token and amount.
  - output_id: The binary encoded output id, this is the result of the encoding of the position
  - state: The current output state:
      - "pending": the default state when creating an output
      - "confirmed": the output is confirmed on the rootchain
      - "exiting": the output is beeing exited
      - "piggybacked": the output is a part of an IFE and has been piggybacked
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  alias Ecto.Atom
  alias Ecto.Multi
  alias Engine.DB.Transaction
  alias ExPlasma.Output.Position

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

  @states [:pending, :confirmed, :exiting, :piggybacked]

  @deposit_output_type ExPlasma.payment_v1()

  schema "outputs" do
    field(:output_id, :binary)
    field(:position, :integer)

    field(:output_type, :integer)
    field(:output_data, :binary)

    field(:state, Atom)

    belongs_to(:spending_transaction, Engine.DB.Transaction)
    belongs_to(:creating_transaction, Engine.DB.Transaction)

    field(:inserted_at, :utc_datetime)
    field(:updated_at, :utc_datetime)

    timestamps()
  end

  defp deposit_changeset(struct, params) do
    struct
    |> state_changeset(params)
    |> input_position_changeset(params)
    |> output_data_changeset(params)
  end

  defp new_changeset(struct, params) do
    struct
    |> state_changeset(params)
    |> output_data_changeset(params)
  end

  defp state_changeset(output, params) do
    output
    |> cast(params, [:state])
    |> validate_required([:state])
    |> validate_inclusion(:state, @states)
  end

  defp output_data_changeset(struct, params) do
    struct
    |> cast(params, [:output_type])
    |> encode_output_data(params)
    |> validate_required([:output_type, :output_data])
  end

  defp input_position_changeset(struct, params) do
    struct
    |> extract_position(params)
    |> encode_output_id(params)
    |> validate_required([:output_id, :position])
  end

  def deposit(blknum, depositor, token, amount) do
    params = %{
      state: :confirmed,
      output_type: @deposit_output_type,
      output_data: %{
        output_guard: depositor,
        token: token,
        amount: amount
      },
      output_id: Position.new(blknum, 0, 0)
    }

    deposit_changeset(%__MODULE__{}, params)
  end

  def new(struct, params) do
    new_changeset(struct, Map.put(params, :state, :pending))
  end

  def piggyback(output), do: state_changeset(output, %{state: :piggybacked})

  def exit(multi, positions) do
    query = usable_for_positions(positions)
    Multi.update_all(multi, :exiting_outputs, query, set: [state: :exiting, updated_at: NaiveDateTime.utc_now()])
  end

  @doc """
  Return all confirmed outputs that have the given positions.
  """
  def usable_for_positions(positions) do
    __MODULE__ |> query_usable() |> query_by_position(positions)
  end

  defp query_usable(query \\ __MODULE__) do
    from(o in query,
      where: is_nil(o.spending_transaction_id) and o.state == "confirmed"
    )
  end

  defp query_by_position(query, positions) do
    from(o in query,
      where: o.position in ^positions
    )
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
