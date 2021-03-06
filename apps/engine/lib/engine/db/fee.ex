defmodule Engine.DB.Fee do
  @moduledoc """
  This module represents computed fees and how they are stored in the database.

  The schema contains the following fields:

  - hash: The sha256 hash of the `term`
  - type:
      - previous_fees: Fees that are still valid for a short period of time after being updated.
        This is to improve the UX by still accepting transactions that was built with a fee that changed just before the submission.

      - merged_fees: A merged map of current and previous fees that is used to validate the output amount of a transaction.

      - current_fees: The currently valid fees.
  - term: The Map of fees per token
  """

  use Ecto.Schema
  use Spandex.Decorators

  import Ecto.Changeset
  import Ecto.Query

  alias Ecto.Atom
  alias Ecto.Term
  alias Engine.Repo

  @required_fields [:type]
  @optional_fields [:term, :inserted_at]
  @allowed_types [:previous_fees, :merged_fees, :current_fees]

  @timestamps_opts [inserted_at: :node_inserted_at, updated_at: :node_updated_at]

  @primary_key false
  schema "fees" do
    field(:hash, :string, primary_key: true)
    field(:type, Atom, primary_key: true)
    field(:term, Term)

    field(:inserted_at, :utc_datetime)

    timestamps()
  end

  def changeset(struct, params) do
    struct
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:type, @allowed_types)
    |> put_hash()
  end

  @decorate trace(service: :ecto, type: :backend)
  def insert(params) do
    %__MODULE__{}
    |> changeset(params)
    |> Repo.insert(on_conflict: :nothing)
  end

  @decorate trace(service: :ecto, type: :backend)
  def remove_previous_fees() do
    query = where(__MODULE__, type: ^:previous_fees)

    Repo.delete_all(query)
  end

  @decorate trace(service: :ecto, type: :backend)
  def fetch_current_fees(), do: fetch(:current_fees)

  @decorate trace(service: :ecto, type: :backend)
  def fetch_merged_fees(), do: fetch(:merged_fees)

  @decorate trace(service: :ecto, type: :backend)
  def fetch_previous_fees(), do: fetch(:previous_fees)

  defp fetch(type) do
    __MODULE__
    |> where([r], r.type == ^type)
    |> order_by([r], desc: r.inserted_at)
    |> limit(1)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      fees -> {:ok, fees}
    end
  end

  defp put_hash(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: changes} ->
        put_change(changeset, :hash, calculate_hash(changes[:term]))

      _ ->
        changeset
    end
  end

  defp calculate_hash(nil), do: hash("")
  defp calculate_hash(term), do: term |> inspect() |> hash()

  defp hash(term) do
    :sha256
    |> :crypto.hash(term)
    |> Base.encode16(case: :lower)
  end
end
