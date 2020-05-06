defmodule Engine.DB.FeeRules do
  @moduledoc """
  This module represents fee rules, which are used to
  compute fees, and how they are stored in the database.
  """

  use Ecto.Schema
  import Ecto.{Changeset, Query}
  alias Engine.Repo
  alias Engine.DB.FeeRules
  alias Ecto.UUID

  @type fee_rule_data_t() :: %{binary() => fee_rule_data_type_t()}
  @type fee_rule_data_type_t() :: %{binary() => fee_rule_data_currency_t()}
  @type fee_rule_data_currency_t() :: %{
          type: binary(),
          symbol: binary(),
          amount: pos_integer(),
          subunit_to_unit: pos_integer(),
          pegged_amount: pos_integer() | nil,
          pegged_subunit_to_unit: pos_integer() | nil,
          pegged_currency: binary() | nil,
          updated_at: binary()
        }

  @primary_key {:uuid, Ecto.UUID, autogenerate: true}
  @timestamps_opts [type: :utc_datetime_usec]

  schema "fee_rules" do
    field(:data, :map, default: %{})
    timestamps()
  end

  def changeset(rate, params \\ %{}) do
    rate
    |> cast(params, [:uuid, :data])
    |> set_id()
  end

  ## Client APIs
  ##

  @doc """
  Fetch latest rules from the database.
  """
  def fetch_latest() do
    FeeRules
    |> select([r], r)
    |> order_by([r], desc: r.inserted_at)
    |> limit(1)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      rules -> {:ok, rules}
    end
  end

  @doc """
  Add a new rules map to the database.
  """
  def insert_rules(rules) do
    %FeeRules{}
    |> changeset(%{data: rules})
    |> Repo.insert()
  end

  ## Private
  ##

  defp set_id(changeset) do
    case get_field(changeset, :uuid) do
      nil ->
        uuid = UUID.generate()
        put_change(changeset, :uuid, uuid)

      _ ->
        changeset
    end
  end
end
