defmodule Engine.CallbackTest do
  use Engine.DB.DataCase, async: true

  alias Ecto.Multi
  alias Engine.Callback

  describe "update_listener_height/3" do
    test "it stores the listeners new height" do
      events = [build(:deposit_event, height: 100)]

      Multi.new()
      |> Callback.update_listener_height(events, :dog_listener)
      |> Repo.transaction()

      assert listener_for(:dog_listener, height: 100)
    end

    test "it sets the height to the highest event" do
      events = [
        build(:deposit_event, height: 100),
        build(:deposit_event, height: 101),
        build(:deposit_event, height: 103)
      ]

      Multi.new()
      |> Callback.update_listener_height(events, :dog_listener)
      |> Repo.transaction()

      assert listener_for(:dog_listener, height: 103)
    end

    test "does not update height if lower" do
      events = [build(:deposit_event, height: 100)]
      old_events = [build(:deposit_event, height: 1)]

      Multi.new()
      |> Callback.update_listener_height(events, :dog_listener)
      |> Repo.transaction()

      Multi.new()
      |> Callback.update_listener_height(old_events, :dog_listener)
      |> Repo.transaction()

      assert listener_for(:dog_listener, height: 100)
    end
  end

  @doc """
  Check to see if the listener has a given state, like height.

    assert listener_for(:depositor, height: 100)
  """
  defp listener_for(listener, height: height) do
    name = "#{listener}"
    %ListenerState{height: ^height, listener: ^name} = Engine.Repo.get(ListenerState, name)
  end
end
