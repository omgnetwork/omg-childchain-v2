defmodule Bus.EventTest do
  @moduledoc false

  use ExUnit.Case

  alias Bus.Event

  test "creates a root chain event" do
    topic = "Deposit"
    event = :deposit
    payload = ["payload"]

    assert %Event{topic: "root_chain:" <> topic, event: event, payload: payload} ==
             Event.new({:root_chain, topic}, event, payload)
  end

  test "creates a child chain event" do
    topic = "blocks"
    event = :deposit
    payload = ["payload"]

    assert %Event{topic: "child_chain:" <> topic, event: event, payload: payload} ==
             Event.new({:child_chain, topic}, event, payload)
  end
end
