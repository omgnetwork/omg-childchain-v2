defmodule Engine.DB.ListenerState do
  @moduledoc """
  Hold's the last Listener state information, specifically it's height. This is
  used primarily by the Event Listener to keep states across deploys.
  """

  use Ecto.Schema
  use Spandex.Decorators

  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:listener, :string, []}
  schema "listener_states" do
    field(:height, :integer)

    field(:inserted_at, :utc_datetime)
    field(:updated_at, :utc_datetime)
  end

  @fields [:listener, :height]

  def update_height(listener, height) do
    changeset(%__MODULE__{}, %{listener: "#{listener}", height: height})
  end

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
  @decorate trace(service: :ecto, type: :backend)
  def get_height(listener) do
    name = "#{listener}"

    case Engine.Repo.get(__MODULE__, name) do
      nil -> 0
      state -> state.height
    end
  end

  @doc """
  Query to check if the listener state height is less
  than the given height.
  """
  def stale_height(listener, height) do
    name = "#{listener}"

    from(ls in __MODULE__, where: ls.listener == ^name, where: ls.height < ^height)
  end
end
