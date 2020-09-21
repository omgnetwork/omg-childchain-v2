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

  alias __MODULE__.Changeset
  alias __MODULE__.Query
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

  @states [:pending, :confirmed, :spent, :exiting, :piggybacked]
  def states, do: @states

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

  def deposit(blknum, depositor, token, amount) do
    params = %{
      state: :confirmed,
      output_type: ExPlasma.payment_v1(),
      output_data: %{
        output_guard: depositor,
        token: token,
        amount: amount
      },
      output_id: Position.new(blknum, 0, 0)
    }

    Changeset.deposit_changeset(%__MODULE__{}, params)
  end

  def new(struct, params) do
    IO.inspect(params)
    Changeset.new_changeset(struct, Map.put(params, :state, :pending)) |> IO.inspect()
  end

  def spend(struct) do
    Changeset.state_changeset(struct, %{state: :spent})
  end

  def piggyback(output) do
    Changeset.state_changeset(output, %{state: :piggybacked})
  end

  def exit(multi, positions) do
    query = Query.usable_for_positions(positions)
    Multi.update_all(multi, :exiting_outputs, query, set: [state: :exiting, updated_at: NaiveDateTime.utc_now()])
  end
end
