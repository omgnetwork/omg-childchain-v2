defmodule Engine.Fee.Fetcher.Client.Parser.SingleSpecParserTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Engine.Fee.Fetcher.Client.Parser.SingleSpecParser

  @eth <<0::160>>
  @eth_hex "0x" <> Base.encode16(@eth)
  @valid_spec %{
    "amount" => 1,
    "subunit_to_unit" => 1_000_000_000_000_000_000,
    "pegged_amount" => 1,
    "pegged_currency" => "USD",
    "pegged_subunit_to_unit" => 100,
    "updated_at" => "2019-01-01T10:10:00+00:00",
    "symbol" => "ETH",
    "type" => "fixed"
  }

  describe "parse/1" do
    test "correctly parse and return a valid spec" do
      assert {:ok,
              %{
                token: @eth,
                amount: 1,
                subunit_to_unit: 1_000_000_000_000_000_000,
                pegged_amount: 1,
                pegged_currency: "USD",
                pegged_subunit_to_unit: 100,
                updated_at: "2019-01-01T10:10:00+00:00" |> DateTime.from_iso8601() |> elem(1),
                type: :fixed
              }} == SingleSpecParser.parse({@eth_hex, @valid_spec})
    end

    test "accepts a nil value for all pegged fields" do
      spec =
        @valid_spec
        |> Map.put("pegged_amount", nil)
        |> Map.put("pegged_currency", nil)
        |> Map.put("pegged_subunit_to_unit", nil)

      assert {:ok,
              %{
                token: @eth,
                amount: 1,
                subunit_to_unit: 1_000_000_000_000_000_000,
                pegged_amount: nil,
                pegged_currency: nil,
                pegged_subunit_to_unit: nil,
                updated_at: "2019-01-01T10:10:00+00:00" |> DateTime.from_iso8601() |> elem(1),
                type: :fixed
              }} == SingleSpecParser.parse({@eth_hex, spec})
    end

    test "returns ok when given decimal to pegged_amount" do
      spec = Map.put(@valid_spec, "pegged_amount", 0.33)

      assert {:ok,
              %{
                token: @eth,
                amount: 1,
                subunit_to_unit: 1_000_000_000_000_000_000,
                pegged_amount: 0.33,
                pegged_currency: "USD",
                pegged_subunit_to_unit: 100,
                updated_at: "2019-01-01T10:10:00+00:00" |> DateTime.from_iso8601() |> elem(1),
                type: :fixed
              }} == SingleSpecParser.parse({@eth_hex, spec})
    end

    test "returns an `invalid_pegged_fields` error when given a nil pegged_amount alone" do
      spec = Map.put(@valid_spec, "pegged_amount", nil)

      assert {:error, :invalid_pegged_fields} == SingleSpecParser.parse({@eth_hex, spec})
    end

    test "returns an `invalid_pegged_fields` error when given a nil pegged_currency alone" do
      spec = Map.put(@valid_spec, "pegged_currency", nil)

      assert {:error, :invalid_pegged_fields} == SingleSpecParser.parse({@eth_hex, spec})
    end

    test "returns an `invalid_pegged_fields` error when given a nil pegged_subunit_to_unit alone" do
      spec = Map.put(@valid_spec, "pegged_subunit_to_unit", nil)

      assert {:error, :invalid_pegged_fields} == SingleSpecParser.parse({@eth_hex, spec})
    end

    test "returns an `invalid_pegged_subunit_to_unit` error when given a decimal pegged_subunit_to_unit" do
      spec = Map.put(@valid_spec, "pegged_subunit_to_unit", 0.33)

      assert {:error, :invalid_pegged_subunit_to_unit} == SingleSpecParser.parse({@eth_hex, spec})
    end

    test "returns an `invalid_fee_spec` error when given an invalid map" do
      spec = %{"invalid_key" => "something"}

      assert {:error, :invalid_fee_spec} == SingleSpecParser.parse({@eth_hex, spec})
    end

    test "returns an `invalid_fee` error when given a negative fee" do
      spec = Map.put(@valid_spec, "amount", -1)

      assert {:error, :invalid_fee} == SingleSpecParser.parse({@eth_hex, spec})
    end

    test "returns an `invalid_fee` error when given a zero fee" do
      spec = Map.put(@valid_spec, "amount", 0)

      assert {:error, :invalid_fee} == SingleSpecParser.parse({@eth_hex, spec})
    end

    test "returns a `bad_address_encoding` error when given an invalid token" do
      assert {:error, :bad_address_encoding} == SingleSpecParser.parse({"Not a token", @valid_spec})
    end

    test "returns a `bad_address_encoding` error when given a token with a length != 20 bytes" do
      assert {:error, :bad_address_encoding} == SingleSpecParser.parse({"0x0123456789abCdeF", @valid_spec})
    end

    test "returns an `invalid_pegged_amount` error when given a negative pegged_amount" do
      spec = Map.put(@valid_spec, "pegged_amount", -1)

      assert {:error, :invalid_pegged_amount} == SingleSpecParser.parse({@eth_hex, spec})
    end

    test "returns an `invalid_pegged_amount` error when given zero pegged_amount" do
      spec = Map.put(@valid_spec, "pegged_amount", 0)

      assert {:error, :invalid_pegged_amount} == SingleSpecParser.parse({@eth_hex, spec})
    end

    test "returns an `invalid_pegged_currency` error when given a non binary pegged_currency" do
      spec = Map.put(@valid_spec, "pegged_currency", 12)

      assert {:error, :invalid_pegged_currency} == SingleSpecParser.parse({@eth_hex, spec})
    end

    test "returns an `invalid_pegged_subunit_to_unit` error when given a negative pegged_subunit_to_unit" do
      spec = Map.put(@valid_spec, "pegged_subunit_to_unit", -1)

      assert {:error, :invalid_pegged_subunit_to_unit} == SingleSpecParser.parse({@eth_hex, spec})
    end

    test "returns an `invalid_pegged_subunit_to_unit` error when given a zero pegged_subunit_to_unit" do
      spec = Map.put(@valid_spec, "pegged_subunit_to_unit", 0)

      assert {:error, :invalid_pegged_subunit_to_unit} == SingleSpecParser.parse({@eth_hex, spec})
    end

    test "returns an `invalid_subunit_to_unit` error when given a negative subunit_to_unit" do
      spec = Map.put(@valid_spec, "subunit_to_unit", -1)

      assert {:error, :invalid_subunit_to_unit} == SingleSpecParser.parse({@eth_hex, spec})
    end

    test "returns an `invalid_subunit_to_unit` error when given a zero subunit_to_unit" do
      spec = Map.put(@valid_spec, "subunit_to_unit", 0)

      assert {:error, :invalid_subunit_to_unit} == SingleSpecParser.parse({@eth_hex, spec})
    end

    test "returns an `invalid_timestamp` error when given an invalid binary datetime" do
      spec = Map.put(@valid_spec, "updated_at", "invalid_date")

      assert {:error, :invalid_timestamp} == SingleSpecParser.parse({@eth_hex, spec})
    end
  end
end
