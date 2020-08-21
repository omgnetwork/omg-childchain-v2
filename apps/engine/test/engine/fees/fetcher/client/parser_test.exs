defmodule Engine.Fees.Fetcher.Client.ParserTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Engine.Fees.Fetcher.Client.Parser

  @moduletag :capture_log

  @eth <<0::160>>
  describe "parse/1" do
    test "successfuly parses valid data" do
      json = ~s(
          {
            "1": {
              "0x0000000000000000000000000000000000000000": {
                "type": "fixed",
                "symbol": "ETH",
                "amount": 43000000000000,
                "subunit_to_unit": 1000000000000000000,
                "pegged_amount": null,
                "pegged_currency": null,
                "pegged_subunit_to_unit": null,
                "updated_at": "2019-01-01T10:10:00+00:00"
              },
              "0x11B7592274B344A6be0Ace7E5D5dF4348473e2fa": {
                "type": "fixed",
                "symbol": "FEE",
                "amount": 1000000000000000000,
                "subunit_to_unit": 1000000000000000000,
                "pegged_amount": null,
                "pegged_currency": null,
                "pegged_subunit_to_unit": null,
                "updated_at": "2019-01-01T10:10:00+00:00"
              },
              "0x942f123b3587EDe66193aa52CF2bF9264C564F87": {
                "type": "fixed",
                "symbol": "OMG",
                "amount": 8600000000000000,
                "subunit_to_unit": 1000000000000000000,
                "pegged_amount": null,
                "pegged_currency": null,
                "pegged_subunit_to_unit": null,
                "updated_at": "2019-01-01T10:10:00+00:00"
              }
            },
            "2": {
              "0x0000000000000000000000000000000000000000": {
                "type": "fixed",
                "symbol": "ETH",
                "amount": 41000000000000,
                "subunit_to_unit": 1000000000000000000,
                "pegged_amount": null,
                "pegged_currency": null,
                "pegged_subunit_to_unit": null,
                "updated_at": "2019-01-01T10:10:00+00:00"
              }
            }
          }
      )

      assert {:ok, tx_type_map} = Parser.parse(json)
      assert tx_type_map[1][@eth][:amount] == 43_000_000_000_000
      assert tx_type_map[1][@eth][:updated_at] == "2019-01-01T10:10:00+00:00" |> DateTime.from_iso8601() |> elem(1)

      assert tx_type_map[1][Base.decode16!("942f123b3587EDe66193aa52CF2bF9264C564F87", case: :mixed)][:amount] ==
               8_600_000_000_000_000

      assert tx_type_map[1][Base.decode16!("11B7592274B344A6be0Ace7E5D5dF4348473e2fa", case: :mixed)][:amount] ==
               1_000_000_000_000_000_000

      assert tx_type_map[2][@eth][:amount] == 41_000_000_000_000
    end

    test "successfuly parses an empty fee spec map" do
      assert {:ok, %{}} = Parser.parse("{}")
    end

    test "returns an `invalid_tx_type` error when given a non integer tx type" do
      json = ~s({
        "non_integer_key": {
          "0x0000000000000000000000000000000000000000": {
            "type": "fixed",
            "symbol": "ETH",
            "amount": 4,
            "subunit_to_unit": 1000000000000000000,
            "pegged_amount": 1,
            "pegged_currency": "USD",
            "pegged_subunit_to_unit": 100,
            "updated_at": "2019-01-01T10:10:00+00:00",
            "error_reason": "Non integer key results with :invalid_tx_type error"
          }
        }
      })

      assert {:error, [{:error, :invalid_tx_type, "non_integer_key", 0}]} == Parser.parse(json)
    end

    test "returns an `invalid_json_format` error when json is not in the correct format" do
      json = ~s({
        "1": {
          "0x0000000000000000000000000000000000000000": {
            "type": "fixed",
            "symbol": "ETH",
            "subunit_to_unit": 1000000000000000000,
            "pegged_amount": 1,
            "pegged_currency": "USD",
            "pegged_subunit_to_unit": 100,
            "updated_at": "2019-01-01T10:10:00+00:00",
            "error_reason": "Missing `amount` key in fee specs"
          }
        }
      })
      assert {:error, [{:error, :invalid_fee_spec, _, _}]} = Parser.parse(json)
    end

    test "`duplicate_token` is not detected by the parser, first occurance takes precedence" do
      json = ~s({
        "1": {
          "0x0000000000000000000000000000000000000000": {
            "type": "fixed",
            "symbol": "ETH",
            "amount": 1,
            "subunit_to_unit": 1000000000000000000,
            "pegged_amount": 1,
            "pegged_currency": "USD",
            "pegged_subunit_to_unit": 100,
            "updated_at": "2019-01-01T10:10:00+00:00"
          },
          "0x0000000000000000000000000000000000000000": {
            "type": "fixed",
            "symbol": "ETH",
            "amount": 2,
            "subunit_to_unit": 1000000000000000000,
            "pegged_amount": 1,
            "pegged_currency": "USD",
            "pegged_subunit_to_unit": 100,
            "updated_at": "2019-01-01T10:10:00+00:00"
          }
        }
      })
      assert {:ok, %{1 => %{@eth => %{amount: 1}}}} = Parser.parse(json)
    end
  end
end
