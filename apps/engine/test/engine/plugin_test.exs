defmodule Engine.PluginTest do
  use ExUnit.Case
  alias Engine.Plugin

  test "it stores the listeners new height" do
    Plugin.verify(true, true, false)
    true = Code.ensure_loaded?(Gas)
    %{fast: 80.0, fastest: 85.0, low: 33.0, name: "Geth", standard: 50.0} = gas = apply(Gas, :get, [1])
    assert is_struct(gas)
    assert Gas = Map.get(gas, :__struct__)
    :code.purge(Gas)
    :code.delete(Gas)
    false = Code.ensure_loaded?(Gas)
  end
end
