defmodule Engine.Fees.Adapters.Parser.JsonTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Engine.Fees.Adapters.Parser.Json

  @eth <<0::160>>

  describe "parse/1" do
    test "successfuly parses valid data" do
      json = ~s(
        {
          "1": [
            {
              "token": "0x0000000000000000000000000000000000000000",
              "amount": 2,
              "subunit_to_unit": 1000000000000000000,
              "pegged_amount": 1,
              "pegged_currency": "USD",
              "pegged_subunit_to_unit": 100,
              "updated_at": "2019-01-01T10:10:00+00:00"
            },
            {
              "token": "0xd26114cd6ee289accf82350c8d8487fedb8a0c07",
              "amount": 1,
              "subunit_to_unit": 1000000000000000000,
              "pegged_amount": 1,
              "pegged_currency": "USD",
              "pegged_subunit_to_unit": 100,
              "updated_at": "2019-01-01T10:10:00+00:00"
            },
            {
              "token": "0xa74476443119a942de498590fe1f2454d7d4ac0d",
              "amount": 4,
              "subunit_to_unit": 1000000000000000000,
              "pegged_amount": 1,
              "pegged_currency": "USD",
              "pegged_subunit_to_unit": 100,
              "updated_at": "2019-01-01T10:10:00+00:00"
            }
          ],
        "2": [
          {
            "token": "0x0000000000000000000000000000000000000000",
            "amount": 4,
            "subunit_to_unit": 1000000000000000000,
            "pegged_amount": 1,
            "pegged_currency": "USD",
            "pegged_subunit_to_unit": 100,
            "updated_at": "2019-01-01T10:10:00+00:00"
          }
        ]
        }
      )

      assert {:ok, tx_type_map} = Json.parse(json)
      assert tx_type_map[1][@eth][:amount] == 2
      assert tx_type_map[1][Base.decode16!("d26114cd6ee289accf82350c8d8487fedb8a0c07", case: :mixed)][:amount] == 1
      assert tx_type_map[1][Base.decode16!("a74476443119a942de498590fe1f2454d7d4ac0d", case: :mixed)][:amount] == 4
      assert tx_type_map[2][@eth][:amount] == 4
    end

    test "successfuly parses an empty fee spec list" do
      assert {:ok, %{}} = Json.parse("[]")
    end

    test "successfuly parses an empty fee spec map" do
      assert {:ok, %{}} = Json.parse("{}")
    end

    test "returns an `invalid_tx_type` error when given a non integer tx type" do
      json = ~s({
        "non_integer_key": [
          {
            "token": "0x0000000000000000000000000000000000000000",
            "amount": 4,
            "subunit_to_unit": 1000000000000000000,
            "pegged_amount": 1,
            "pegged_currency": "USD",
            "pegged_subunit_to_unit": 100,
            "updated_at": "2019-01-01T10:10:00+00:00",
            "error_reason": "Non integer key results with :invalid_tx_type error"
          }
        ]
      })

      assert {:error, [{:error, :invalid_tx_type, "non_integer_key", 0}]} == Json.parse(json)
    end

    test "returns an `invalid_json_format` error when json is not in the correct format" do
      # json is a list
      json = ~s([{
        "1": [
          {
            "token": "0x0000000000000000000000000000000000000000",
            "amount": 1,
            "subunit_to_unit": 1000000000000000000,
            "pegged_amount": 1,
            "pegged_currency": "USD",
            "pegged_subunit_to_unit": 100,
            "updated_at": "2019-01-01T10:10:00+00:00"
          }
        ]
      }])
      assert {:error, [{:error, :invalid_json_format, nil, nil}]} = Json.parse(json)
    end

    test "returns a `duplicate_token` error when tokens are duplicated for the same tx type" do
      json = ~s({
        "1": [
          {
            "token": "0x0000000000000000000000000000000000000000",
            "amount": 1,
            "subunit_to_unit": 1000000000000000000,
            "pegged_amount": 1,
            "pegged_currency": "USD",
            "pegged_subunit_to_unit": 100,
            "updated_at": "2019-01-01T10:10:00+00:00"
          },
          {
            "token": "0x0000000000000000000000000000000000000000",
            "amount": 2,
            "subunit_to_unit": 1000000000000000000,
            "pegged_amount": 1,
            "pegged_currency": "USD",
            "pegged_subunit_to_unit": 100,
            "updated_at": "2019-01-01T10:10:00+00:00"
          }
        ]
      })
      assert {:error, [{:error, :duplicate_token, 1, 2}]} = Json.parse(json)
    end
  end
end
