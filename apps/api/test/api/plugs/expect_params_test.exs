defmodule API.Plugs.ExpectParamsTest do
  use ExUnit.Case, async: false
  use Plug.Test

  alias API.Plugs.ExpectParams

  test "raises an error if a param is missing" do
    assert_raise(ArgumentError, "missing required key \"foo\"", fn ->
      call_plug("/", %{})
    end)
  end

  test "does not raise if params exist" do
    resp = call_plug("/", %{foo: "hi"})
    assert resp.params == %{"foo" => "hi"}
  end

  test "raises error for a given path" do
    assert_raise(ArgumentError, "missing required key \"foo\"", fn ->
      call_plug("/", %{})
    end)
  end

  test "does not raises error for a non matching path" do
    resp = call_plug("/dog", %{bar: "hi"})
    assert resp.params == %{"bar" => "hi"}
  end

  test "raises for an empty string" do
    assert_raise(ArgumentError, "missing required key \"foo\"", fn ->
      call_plug("/", %{foo: ""})
    end)
  end

  test "raises for an blank string" do
    assert_raise(ArgumentError, "missing required key \"foo\"", fn ->
      call_plug("/", %{foo: "  "})
    end)
  end

  defp call_plug(path, params) do
    :get
    |> conn(path, params)
    |> ExpectParams.call(key: "foo", path: "/")
  end
end