defmodule Engine.DB.Fees do
  @moduledoc """
  This module represents computed fees and how they
  are stored in the database.
  """

  use Ecto.Schema
  use Spandex.Decorators
  import Ecto.Changeset
  import Ecto.Query
  alias Ecto.UUID
  alias Engine.DB.FeeRules
  alias Engine.DB.Fees
  alias Engine.Repo

  @type fee_data_t() :: %{binary() => fee_data_type_t()}
  @type fee_data_type_t() :: %{binary() => fee_data_currency_t()}
  @type fee_data_currency_t() :: %{
          type: binary(),
          symbol: binary(),
          amount: pos_integer(),
          subunit_to_unit: pos_integer(),
          pegged_amount: pos_integer() | nil,
          pegged_subunit_to_unit: pos_integer() | nil,
          pegged_currency: binary() | nil,
          updated_at: binary()
        }

  @primary_key {:uuid, UUID, autogenerate: true}

  schema "fees" do
    field(:data, :map, default: %{})

    belongs_to(
      :fee_rules,
      FeeRules,
      foreign_key: :fee_rules_uuid,
      references: :uuid,
      type: UUID
    )

    timestamps(type: :utc_datetime)
  end

  def changeset(fees, params \\ %{}) do
    fees
    |> cast(params, [:uuid, :data, :fee_rules_uuid])
    |> validate_required(:fee_rules_uuid)
    |> set_id()
  end

  @doc """
  Fetch latest fees from the database.
  """
  @decorate trace(service: :ecto, type: :backend)
  def fetch_latest() do
    Fees
    |> select([r], r)
    |> order_by([r], desc: r.inserted_at)
    |> limit(1)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      fees -> {:ok, fees}
    end
  end

  @doc """
  Add a new fees map to the database.
  """
  @decorate trace(service: :ecto, type: :backend)
  def insert_fees(fees, fee_rules_uuid) do
    %Fees{}
    |> changeset(%{data: fees, fee_rules_uuid: fee_rules_uuid})
    |> Repo.insert()
  end

  defp set_id(changeset) do
    case get_field(changeset, :uuid) do
      nil ->
        put_change(changeset, :uuid, UUID.generate())

      _ ->
        changeset
    end
  end
end
