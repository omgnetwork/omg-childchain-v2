defmodule Engine.DB.ListenerState do
  @moduledoc """
  Hold's the last Listener state information, specifically it's height. This is
  used primarily by the Event Listener to keep states across deploys.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:listener, :string, []}
  schema "listener_states" do
    field(:height, :integer)

    timestamps(type: :utc_datetime)
  end

  @fields [:listener, :height]

  def changeset(struct, params) do
    struct
    |> cast(params, @fields)
    |> validate_required(@fields)
    |> validate_number(:height, greater_than_or_equal_to: 0)
  end

  @doc """
  Return the height for the listener. Defaults to 0.
  """
  @spec get_height(atom()) :: non_neg_integer()
  def get_height(listener) do
    case Engine.Repo.get(__MODULE__, "#{listener}") do
      nil -> 0
      state -> state.height
    end
  end
end
