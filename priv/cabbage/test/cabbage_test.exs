defmodule CabbageTest do
  use ExUnit.Case
  doctest Cabbage

  test "greets the world" do
    assert Cabbage.hello() == :world
  end
end
