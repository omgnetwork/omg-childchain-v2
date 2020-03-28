defmodule RpcTest do
  use ExUnit.Case
  doctest Rpc

  test "greets the world" do
    assert Rpc.hello() == :world
  end
end
