defmodule Engine.DB.PaidFee do
  @moduledoc """
  Represents fees collected for a transaction.

  Fields:

  transaction_id - foreign key to the transaction which created the fees
  currency - currency of the fees
  amount - amount paid
  """

  use Ecto.Schema
  use Spandex.Decorators

  import Ecto.Changeset

  alias Engine.DB.Transaction

  @type t() :: %{
          transaction: Transaction.t(),
          transaction_id: pos_integer(),
          id: pos_integer(),
          inserted_at: DateTime.t(),
          currency: binary(),
          amount: pos_integer()
        }

  @required_fields [:currency, :amount]

  @timestamps_opts [inserted_at: :node_inserted_at]

  schema "paid_fees" do
    belongs_to(:transaction, Transaction)
    field(:currency, :binary)
    field(:amount, :integer)

    field(:inserted_at, :utc_datetime)

    timestamps()
  end

  def changeset(struct, params) do
    struct
    |> cast(params, @required_fields)
    |> validate_required(@required_fields)
  end
end
