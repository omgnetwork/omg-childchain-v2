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
      - :pending - the default state when creating an output
      - :confirmed - the output is confirmed on the rootchain
      - :spent - the output is spent by a transaction
      - :exiting - the output is being exited
      - :piggybacked - the output is a part of an IFE and has been piggybacked
  - blknum in short, it tracks on which plasma block a specific output was created for the simple reason that
    outputs need to be "approved" (state is moved to confirmed) after a plasma block is mined on ethereum
  """

  use Ecto.Schema
  import Ecto.Query, only: [from: 2]

  alias __MODULE__.OutputChangeset
  alias __MODULE__.OutputQuery
  alias Ecto.Atom
  alias Ecto.Multi
  alias Engine.Configuration
  alias Engine.DB.Transaction
  alias Engine.Repo
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
          blknum: pos_integer(),
          state: String.t(),
          updated_at: DateTime.t()
        }

  @timestamps_opts [inserted_at: :node_inserted_at, updated_at: :node_updated_at]

  @states [:pending, :confirmed, :spent, :exiting, :piggybacked]

  def states(), do: @states

  schema "outputs" do
    field(:output_id, :binary)
    field(:position, :integer)

    field(:output_type, :integer)
    field(:output_data, :binary)

    field(:state, Atom)
    field(:blknum, :integer)

    belongs_to(:spending_transaction, Engine.DB.Transaction)
    belongs_to(:creating_transaction, Engine.DB.Transaction)

    field(:inserted_at, :utc_datetime)
    field(:updated_at, :utc_datetime)

    timestamps()
  end

  @doc """
  Generates an output changeset corresponding to a deposit output being inserted.
  The output state is `:confirmed`.
  """
  @spec deposit(pos_integer(), <<_::160>>, <<_::160>>, pos_integer()) :: Ecto.Changeset.t()
  def deposit(blknum, depositor, token, amount) do
    params = %{
      state: :confirmed,
      output_type: ExPlasma.payment_v1(),
      output_data: %{
        output_guard: depositor,
        token: token,
        amount: amount
      },
      blknum: blknum,
      output_id: Position.new(blknum, 0, 0)
    }

    OutputChangeset.deposit(%__MODULE__{}, params)
  end

  @doc """
  Generates an output changeset corresponding to a new output being inserted.
  The output state is `:pending`.
  """
  @spec new(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def new(struct, params) do
    case Configuration.ufo() do
      true ->
        OutputChangeset.new(struct, Map.put(params, :state, :confirmed))

      false ->
        OutputChangeset.new(struct, Map.put(params, :state, :pending))
    end
  end

  @doc """
  Generates an output changeset corresponding to an output being spent.
  The output state is `:spent`.
  """
  @spec spend(%__MODULE__{}) :: Ecto.Changeset.t()
  def spend(struct) do
    OutputChangeset.state(struct, %{state: :spent})
  end

  @doc """
  Generates an output changeset corresponding to an output being spent.
  The output state is `:spent`.
  """
  @spec confirmed(%__MODULE__{}) :: Ecto.Changeset.t()
  def confirmed(struct) do
    OutputChangeset.state(struct, %{state: :confirmed})
  end

  @doc """
  Generates an output changeset corresponding to an output being piggybacked.
  The output state is `:piggybacked`.
  """
  @spec piggyback(%__MODULE__{}) :: Ecto.Changeset.t()
  def piggyback(output) do
    OutputChangeset.state(output, %{state: :piggybacked})
  end

  @doc """
  Updates the given multi by setting all outputs found at the given `positions` to an `:exiting` state.
  """
  @spec exit(Multi.t(), list(pos_integer())) :: Multi.t()
  def exit(multi, positions) do
    query = OutputQuery.usable_for_positions(positions)
    Multi.update_all(multi, :exiting_outputs, query, set: [state: :exiting, updated_at: NaiveDateTime.utc_now()])
  end

  def confirm(mined_child_block) do
    Repo.update_all(
      from(p in __MODULE__,
        where: p.blknum <= ^mined_child_block and p.blknum > ^mined_child_block - 1000 and p.state == :pending,
        update: [set: [state: :confirmed]]
      ),
      []
    )
  end
end
