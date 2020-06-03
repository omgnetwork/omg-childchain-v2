defmodule API.Plugs.ExpectParamsTest do
  use Engine.DB.DataCase, async: false
  use Plug.Test

  alias API.Plugs.ExpectParams
  alias API.Plugs.ExpectParams.MissingParamsError

  @moduletag :focus

  test "raises an error if a param is missing" do
    assert_raise(MissingParamsError, "Expected param key \"foo\" but was not found", fn ->
      call_plug("/", %{})
    end)
  end

  test "does not raise if params exist" do
    resp = call_plug("/", %{foo: "hi"})
    assert resp.params == %{"foo" => "hi"}
  end

  test "raises error for a given path" do
    assert_raise(MissingParamsError, "Expected param key \"foo\" but was not found", fn ->
      call_plug("/dog", %{})
    end)
  end

  test "does not raises error for a non matching path" do
    resp = call_plug("/dog", %{bar: "hi"})
    assert resp.params == %{"bar" => "hi"}
  end

  test "raises for an empty string" do
    assert_raise(MissingParamsError, "Expected param key \"foo\" but was not found", fn ->
      call_plug("/dog", %{foo: ""})
    end)
  end

  test "raises for an blank string" do
    assert_raise(MissingParamsError, "Expected param key \"foo\" but was not found", fn ->
      call_plug("/dog", %{foo: "  "})
    end)
  end

  defp call_plug(path, params) do
    :get
    |> conn(path, params)
    |> ExpectParams.call(key: "foo", path: "/")
  end
end
