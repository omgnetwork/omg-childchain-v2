defmodule APITest do
  use ExUnit.Case
  doctest API

  test "greets the world" do
    assert API.hello() == :world
  end
end
