defmodule Engine.Feefeed.Rules.ParserTest do
  use ExUnit.Case, async: true
  alias Engine.Feefeed.Rules.Parser

  #  doctest Parser

  describe "decode_and_validate/1" do
    test "parses a sample fee rules JSON" do
      {:ok, rules} = File.read("test/support/fee_rules.json")
      assert {:ok, _} = Parser.decode_and_validate(rules)
    end

    test "returns an error if empty" do
      assert {:error, %Jason.DecodeError{}} = Parser.decode_and_validate("")
    end

    test "returns an error if invalid" do
      assert {:error, %Jason.DecodeError{}} = Parser.decode_and_validate(~s({"key_1":"value_1", "key_2: "value_2"}))
    end

    test "returns an error if the rules don't match the JSON schema" do
      assert {:error,
              [
                {"Schema does not allow additional properties.", "#/key_1"},
                {"Schema does not allow additional properties.", "#/key_2"}
              ]} = Parser.decode_and_validate(~s({"key_1":"value_1", "key_2": "value_2"}))
    end
  end
end
