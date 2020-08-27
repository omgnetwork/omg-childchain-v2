defmodule Engine.Callbacks.InFlightExitStartedTest do
  @moduledoc false
  use Engine.DB.DataCase, async: true

  alias Engine.Callbacks.InFlightExitStarted
  alias Engine.DB.ListenerState
  alias Engine.DB.Output

  describe "callback/1" do
    test "marks input that is exiting" do
      %{outputs: [%{position: position}]} = insert(:deposit_transaction, blknum: 1000)

      events = [build(:in_flight_exit_started_event, positions: [position], height: 100)]

      assert {:ok, %{exiting_outputs: {1, nil}}} = InFlightExitStarted.callback(events, :in_flight_exit_started)
      assert listener_for(:in_flight_exit_started, height: 100)

      query = from(o in Output, where: o.position == ^position, select: o.state)
      assert "exiting" = Repo.one(query)
    end

    test "marks multiple inputs in a single IFE that are exiting" do
      %{outputs: [%{position: pos1}]} = insert(:deposit_transaction, blknum: 1000)
      %{outputs: [%{position: pos2}]} = insert(:deposit_transaction, blknum: 2000)

      events = [build(:in_flight_exit_started_event, positions: [pos1, pos2], height: 101)]

      assert {:ok, %{exiting_outputs: {2, nil}}} = InFlightExitStarted.callback(events, :in_flight_exit_started)

      assert listener_for(:in_flight_exit_started, height: 101)

      query = from(o in Output, where: o.position in [^pos1, ^pos2], select: o.state)
      assert ["exiting", "exiting"] = Repo.all(query)
    end

    test "marks multiple IFEs as exiting" do
      %{outputs: [%{position: pos1}]} = insert(:deposit_transaction, blknum: 4000)
      %{outputs: [%{position: pos2}]} = insert(:deposit_transaction, blknum: 5000)
      %{outputs: [%{position: pos3}]} = insert(:deposit_transaction, blknum: 6000)
      %{outputs: [%{position: pos4}]} = insert(:deposit_transaction, blknum: 7000)

      events = [
        build(:in_flight_exit_started_event, positions: [pos1, pos2], height: 101),
        build(:in_flight_exit_started_event, positions: [pos3, pos4], height: 102)
      ]

      assert {:ok, %{exiting_outputs: {4, nil}}} = InFlightExitStarted.callback(events, :exit_started)

      assert listener_for(:exit_started, height: 102)

      query = from(o in Output, where: o.position in [^pos1, ^pos2, ^pos3, ^pos4], select: o.state)
      assert ["exiting", "exiting", "exiting", "exiting"] = Repo.all(query)
    end
  end

  # Check to see if the listener has a given state, like height.
  #   assert listener_for(:depositor, height: 100)
  defp listener_for(listener, height: height) do
    name = "#{listener}"
    %ListenerState{height: ^height, listener: ^name} = Engine.Repo.get(ListenerState, name)
  end
end
