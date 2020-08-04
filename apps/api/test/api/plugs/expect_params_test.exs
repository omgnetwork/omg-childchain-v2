defmodule API.Plugs.ExpectParamsTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias API.Plugs.ExpectParams

  defmodule DummyReponder do
    def respond(_conn, data), do: data
  end

  @expected_params %{
    "foo" => [
      %{name: "foo", type: :hex, required: true},
      %{name: "bar", type: :hex, required: false}
    ]
  }

  describe "call/2" do
    test "returns the conn with params when valid, default optional to nil" do
      params = %{"foo" => "0x01"}
      assert %{params: validated_params} = call_plug("foo", params)
      assert validated_params == Map.put(params, "bar", nil)
    end

    test "calls responder with a `missing_required_param` error when a required param is missing" do
      assert call_plug("foo", %{}) == {:error, :missing_required_param, "missing required key 'foo'"}
    end

    test "returns the conn unchanged if the path is not valid" do
      conn = conn(:get, "undefined", %{})
      assert ExpectParams.call(conn, expected_params: @expected_params, responder: DummyReponder) == conn
    end
  end

  defp call_plug(path, params) do
    :get
    |> conn(path, params)
    |> ExpectParams.call(expected_params: @expected_params, responder: DummyReponder)
  end
end
