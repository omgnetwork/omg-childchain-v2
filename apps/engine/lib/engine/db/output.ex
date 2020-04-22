defmodule Engine.DB.Output do
  @moduledoc """
  Ecto schema for Outputs in the system. The Output can exist in two forms:

  * Being built, as a new unspent output (Output). Since the blocks have not been formed, the full utxo position
  information does not exist for the given Output. We only really know the oindex at this point.

  * Being formed into a block via the transaction. At this point we should have all the information available to
  create a full Output position for this.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @error_messages [
    cannot_be_zero: "can't be zero",
    exceeds_maximum: "can't exceed maximum value"
  ]

  @states [
    "pending",
    "confirming",
    "confirmed",
    "spending",
    "spent",
    "exiting",
    "exited"
  ]

  schema "outputs" do
    # Output position information
    field(:position, :integer)

    field(:output_type, :integer)
    field(:output_data, :map, default: %{})
    field(:output_id, :map, default: %{})

    field(:state, :string, default: "pending")

    belongs_to(:spending_transaction, Engine.Transaction2)
    belongs_to(:creating_transaction, Engine.Transaction2)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Default changset. Generates the Output and ensures
  that it meets the state-less validations.
  """
  def changeset(struct, params) do
    struct
    |> cast(params, [:output_type, :output_data, :output_id])
  end

end
