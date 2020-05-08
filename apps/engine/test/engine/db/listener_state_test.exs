defmodule Engine.DB.ListenerStateTest do
  use Engine.DB.DataCase, async: true
  doctest Engine.DB.ListenerState, import: true

  alias Engine.DB.ListenerState

  describe "changeset/2" do
    test "validates that height is greater than or equal to 0" do
      params = %{listener: "depositor", height: -1}
      changeset = ListenerState.changeset(%ListenerState{}, params)

      assert [height: _] = changeset.errors
    end
  end

  describe "get_height/1" do
    test "returns listener height" do
      params = %{listener: "depositor", height: 1}
      changeset = ListenerState.changeset(%ListenerState{}, params)
      _ = Repo.insert(changeset)

      assert 1 == ListenerState.get_height(:depositor)
    end

    test "returns 0 if listener state not found" do
      assert 0 == ListenerState.get_height(:not_a_depositor)
    end
  end
end
