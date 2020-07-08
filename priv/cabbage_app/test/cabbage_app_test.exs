defmodule CabbageAppTest do
  use ExUnit.Case
  doctest Cabbage

  test "greets the world" do
    assert CabbageApp.hello() == :world
  end
end
