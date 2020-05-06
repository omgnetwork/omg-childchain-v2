defmodule Engine.Feefeed.Rules.Parser do
  @moduledoc """
  This module is used to parse fee rules and ensure
  they match the JSON schema defined below.
  """
  alias ExJsonSchema.Validator
  alias Jason.DecodeError

  # We're only allowing fixed fees right now
  # Once we support eth <> ERC-20 token rates retrieval,
  # this can be changed to be a pre-defined list of
  # ERC-20 tokens.
  @schema %{
    "type" => "object",
    "additionalProperties" => false,
    "patternProperties" => %{
      "^[[:digit:]]+$" => %{
        "type" => "object",
        "additionalProperties" => false,
        "patternProperties" => %{
          "^0x[[:alnum:]]+$" => %{
            "type" => "object",
            "additionalProperties" => false,
            "properties" => %{
              "type" => %{
                "type" => "string",
                "enum" => ["fixed"]
              },
              "symbol" => %{"type" => "string"},
              "amount" => %{"type" => ["number", "null"]},
              "subunit_to_unit" => %{"type" => "number"},
              "pegged_amount" => %{"type" => ["number", "null"]},
              "pegged_currency" => %{
                "type" => ["string", "null"],
                "enum" => [nil]
              },
              "pegged_subunit_to_unit" => %{"type" => ["number", "null"]}
            }
          }
        }
      }
    }
  }

  @doc ~S"""
  Decode the given `string` JSON into a map. Returns `{:ok, map}` if `string` is
  a valid JSON, otherwise returns `{:error, reason}`.

  ## Examples

      iex> Engine.Feefeed.Rules.Parser.decode(~s|
      ...> {
      ...>   "hello": "world"
      ...> }
      ...> |)
      {:ok, %{"hello" => "world"}}

  If an invalid JSON is given as `string`:

      iex> Engine.Feefeed.Rules.Parser.decode(~s|invalid|)
      {:error, %Jason.DecodeError{data: "invalid", position: 0, token: nil}}

  """
  @spec decode(String.t()) :: {:ok, map()} | {:error, %DecodeError{}}
  def decode(string), do: Jason.decode(string)

  @doc ~S"""
  Decode the given `string` JSON into a map and validate it against rule schema.
  Returns `{:ok, map}` if `string` is a valid JSON and passed the schema validation,
  otherwise returns `{:error, reason}`.

  ## Examples

      iex> Engine.Feefeed.Rules.Parser.decode_and_validate(~s|
      ...> {
      ...>   "1": {
      ...>     "0x86367c0e517622DAcdab379f2de389c3C9524345": {
      ...>       "symbol": "UPUSD",
      ...>       "type": "fixed",
      ...>       "amount": 40000,
      ...>       "subunit_to_unit": 1000000
      ...>     }
      ...>   }
      ...> }
      ...> |)
      {:ok,
       %{
         "1" => %{
           "0x86367c0e517622DAcdab379f2de389c3C9524345" => %{
             "symbol" => "UPUSD",
             "subunit_to_unit" => 1000000,
             "amount" => 40000,
             "type" => "fixed"
           }
         }
       }}

  The provided string must be a valid JSON:

      iex> Engine.Feefeed.Rules.Parser.decode_and_validate(~s|invalid|)
      {:error, %Jason.DecodeError{data: "invalid", position: 0, token: nil}}

  The provided JSON should have payment version as its root key:

      iex> Engine.Feefeed.Rules.Parser.decode_and_validate(~s|
      ...> {
      ...>   "invalidVer": {}
      ...> }
      ...> |)
      {:error, [{"Schema does not allow additional properties.", "#/invalidVer"}]}

  The provided JSON should have uppercase token symbol as its secondary key:

      iex> Engine.Feefeed.Rules.Parser.decode_and_validate(~s|
      ...> {
      ...>   "1": {
      ...>     "invalidToken": {}
      ...>   }
      ...> }
      ...> |)
      {:error, [{"Schema does not allow additional properties.", "#/1/invalidToken"}]}

  The provided JSON should have object as a value to secondary key:

      iex> Engine.Feefeed.Rules.Parser.decode_and_validate(~s|
      ...> {
      ...>   "1": {
      ...>     "0x86367c0e": "invalidVal"
      ...>   }
      ...> }
      ...> |)
      {:error, [{"Type mismatch. Expected Object but got String.", "#/1/0x86367c0e"}]}

  """
  @spec decode_and_validate(String.t()) ::
          {:ok, map()} | {:error, %DecodeError{}} | {:error, nonempty_list()}
  def decode_and_validate(string) do
    with {:ok, res} <- decode(string),
         :ok <- validate(res) do
      {:ok, res}
    end
  end

  @doc ~S"""
  Validates the given `map` against the rule schema. Returns `:ok` if map conforms
  the schema, otherwise returns `{:error, reason}`. The schema is roughly defined
  as follows:

      {
        $payment_version: {
          $token_symbol: {
            "type": "pegged" | "fixed",
            "fee_units": number,
            "fee_subunit_to_units": number,
            "pegged_currency": string,
            "pegged_units": number,
            "pegged_subunit_to_units": number
          }
        }
      }

  whereas `$payment_version` is a number-string (e.g. "1", "2", "3") indicating
  version of a payment in ALD contract, and `$token_symbol` is an uppercase
  letter representing a token (e.g. "OMG", "ETH", "BTC")

  ## Examples

      iex> Engine.Feefeed.Rules.Parser.validate(%{
      ...>   "1" => %{
      ...>     "0x86367c0e517622DAcdab379f2de389c3C9524345" => %{
      ...>       "symbol" => "UPUSD",
      ...>       "subunit_to_unit" => 1000000,
      ...>       "amount" => 40000,
      ...>       "type" => "fixed"
      ...>     }
      ...>   }
      ...> })
      :ok

  The provided map should have payment version as its root key:

      iex> Engine.Feefeed.Rules.Parser.validate(%{
      ...>   "invalidVer" => %{}
      ...> })
      {:error, [{"Schema does not allow additional properties.", "#/invalidVer"}]}

  The provided map should have uppercase token symbol as its secondary key:

      iex> Engine.Feefeed.Rules.Parser.validate(%{
      ...>   "1" => %{
      ...>     "invalidToken" => %{}
      ...>   }
      ...> })
      {:error, [{"Schema does not allow additional properties.", "#/1/invalidToken"}]}

  The provided map should have object as a value to secondary key:

      iex> Engine.Feefeed.Rules.Parser.validate(%{
      ...>   "1" => %{
      ...>     "0x86367c0e" => "invalidVal"
      ...>   }
      ...> })
      {:error, [{"Type mismatch. Expected Object but got String.", "#/1/0x86367c0e"}]}

  """
  @spec validate(map()) :: :ok | {:error, list()}
  def validate(map), do: Validator.validate(@schema, map)
end
