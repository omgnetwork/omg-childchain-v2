defmodule API.Plugs.ExpectParams.ParamsValidatorTest do
  use ExUnit.Case, async: true

  alias API.Plugs.ExpectParams.ParamsValidator

  @expected_params [
    %{name: "foo", type: :hex, required: true},
    %{name: "bar", type: :hex, required: false}
  ]

  describe "validate/2" do
    test "returns a new map of params when valid, default optional to nil" do
      params = %{"foo" => "0x01"}
      assert validate(params) == {:ok, Map.put(params, "bar", nil)}
    end

    test "filters unwanted params" do
      params = %{"foo" => "0x01", "bar" => "0x02", "unwanted" => "param"}
      assert validate(params) == {:ok, Map.drop(params, ["unwanted"])}
    end

    test "returns a `missing_required_param` error when a required param is missing" do
      assert validate(%{}) == {:error, :missing_required_param, "missing required key 'foo'"}
    end

    test "returns a invalid_param_value error when given an empty string" do
      params = %{"foo" => ""}
      assert validate(params) == {:error, :invalid_param_value, "value for key 'foo' is invalid, got: ''"}
    end

    test "returns a invalid_param_value error when given an blank string" do
      params = %{"foo" => "   "}
      assert validate(params) == {:error, :invalid_param_value, "value for key 'foo' is invalid, got: '   '"}
    end

    test "returns a 'invalid_param_type' error when given not given an hex string for a required hex type" do
      params = %{"foo" => "123"}
      assert validate(params) == {:error, :invalid_param_type, "hex values must be prefixed with 0x, got: '123'"}
    end

    test "returns a 'invalid_param_type' error when given not given an hex string for an optional hex type" do
      params = %{"foo" => "0x01", "bar" => "123"}
      assert validate(params) == {:error, :invalid_param_type, "hex values must be prefixed with 0x, got: '123'"}
    end

    test "validates a list of hex values" do
      expected_params = [%{name: "currencies", type: {:list, :hex}, required: true}]
      params = %{"currencies" => ["0x01", "0x02"]}

      assert validate(params, expected_params) == {:ok, params}
    end

    test "invalidates a list of hex values" do
      expected_params = [%{name: "currencies", type: {:list, :hex}, required: true}]
      params = %{"currencies" => ["0x01", 10]}

      assert validate(params, expected_params) ==
               {:error, :invalid_param_type, "hex values must be prefixed with 0x, got: '10'"}
    end

    test "validate non negative integer" do
      expected_params = [%{name: "tx_type", type: :non_neg_integer, required: true}]
      params = %{"tx_type" => 1}

      assert validate(params, expected_params) == {:ok, ^params}
    end
  end

  defp validate(params, expected_params \\ @expected_params) do
    ParamsValidator.validate(params, expected_params)
  end
end
