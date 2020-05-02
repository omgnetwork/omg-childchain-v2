defmodule Engine.SyncedHeight do
  @moduledoc """
  Represent a block of transactions that will be submitted to the contracts.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:listener, :string, []}
  schema "synced_height" do
    # field(:listener, :string)
    field(:height, :integer)

    timestamps(type: :utc_datetime)
  end

  @fields ~w(listener height)a

  def changeset(data, params \\ %{}) do
    data
    |> cast(params, @fields)
    |> validate_required([:listener, :height])
    |> validate_number(:height, greater_than_or_equal_to: 0)
  end

  @spec get_height(atom()) :: non_neg_integer()
  def get_height(listener) do
    case Engine.Repo.get(__MODULE__, "#{listener}") do
      nil -> 0
      synced_height -> synced_height.height
    end
  end
end
