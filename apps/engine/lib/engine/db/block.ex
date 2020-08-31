defmodule Engine.DB.Block do
  @moduledoc """
  Represent a block of transactions that will be submitted to the contracts.
  """

  use Ecto.Schema
  use Spandex.Decorators

  import Ecto.Changeset
  import Ecto.Query

  alias Ecto.Changeset
  alias Ecto.Multi
  alias Engine.DB.Transaction
  alias Engine.Repo
  alias ExPlasma.Merkle

  @type t() :: %{
          transactions: list(Transaction.t()),
          id: pos_integer(),
          state: String.t(),
          number: pos_integer(),
          hash: <<_::256>>,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "blocks" do
    field(:hash, :binary)
    field(:number, :integer)
    field(:state, :string)

    has_many(:transactions, Transaction)

    timestamps(type: :utc_datetime)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:hash, :number, :state])
    |> cast_assoc(:transactions)
    |> unique_constraint(:number)
  end
end
