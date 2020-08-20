defmodule Engine.DB.Fee do
  @moduledoc """
  This module represents computed fees and how they
  are stored in the database.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Engine.Repo

  @required_fields [:term, :type]
  @allowed_types ["previous_fees", "merged_fees", "current_fees"]

  @primary_key false
  schema "fees" do
    field(:hash, :string, primary_key: true)
    field(:type, :string, primary_key: true)
    field(:term, Term)

    field(:inserted_at, :utc_datetime)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, @required_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:type, @allowed_types)
    |> put_hash()
  end

  def insert(params) do
    %__MODULE__{}
    |> changeset(params)
    |> Repo.insert(on_conflict: :nothing)
  end

  def fetch_current_fees(), do: fetch("current_fees")
  def fetch_merged_fees(), do: fetch("merged_fees")
  def fetch_previous_fees(), do: fetch("previous_fees")

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

  defp calculate_hash(term) do
    string = (term && inspect(term)) || ""

    :sha256
    |> :crypto.hash(string)
    |> Base.encode16(case: :lower)
  end
end
