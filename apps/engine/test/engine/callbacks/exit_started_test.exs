defmodule Engine.Callbacks.ExitStartedTest do
  @moduledoc false
  use Engine.DB.DataCase, async: true

  alias Engine.Callbacks.ExitStarted
  alias Engine.DB.ListenerState
  alias Engine.DB.Output

  describe "callback/2" do
    test "marks utxos that are exiting" do
      %{position: position} = insert(:deposit_output, blknum: 1)

      events = [build(:exit_started_event, position: position, height: 100)]

      assert {:ok, %{exiting_outputs: {1, nil}}} = ExitStarted.callback(events, :exit_started)

      assert listener_for(:exit_started, height: 100)

      query = from(o in Output, where: o.position == ^position, select: o.state)
      assert Repo.one(query) == :exiting
    end

    test "marks multiple utxos as exiting" do
      %{position: pos1} = insert(:deposit_output, blknum: 2)
      %{position: pos2} = insert(:deposit_output, blknum: 3)

      events = [
        build(:exit_started_event, position: pos1, height: 101),
        build(:exit_started_event, position: pos2, height: 102)
      ]

      assert {:ok, %{exiting_outputs: {2, nil}}} = ExitStarted.callback(events, :exit_started)

      assert listener_for(:exit_started, height: 102)

      query = from(o in Output, where: o.position in [^pos1, ^pos2], select: o.state)
      assert Repo.all(query) == [:exiting, :exiting]
    end

    test "returns {:ok, :noop} when no event given" do
      assert ExitStarted.callback([], :exit_started) == {:ok, :noop}
    end
  end

  # Check to see if the listener has a given state, like height.
  #   assert listener_for(:depositor, height: 100)
  defp listener_for(listener, height: height) do
    name = "#{listener}"
    %ListenerState{height: ^height, listener: ^name} = Engine.Repo.get(ListenerState, name)
  end
end
