defmodule Engine.Fee.Fetcher.Client.Parser do
  @moduledoc """
  Transaction's fee validation functions
  """

  alias Engine.Fee.Fetcher.Client.Parser.SingleSpecParser

  require Logger

  @typedoc """
  Parsing error type:

  - :duplicate_token - there is a duplicated token for the same tx type
  - :invalid_json_format - the format of the json is invalid (ie: it's an array)
  - :invalid_tx_type - the tx type can't be parsed to an integer
  """

  @type parsing_error() ::
          SingleSpecParser.parsing_error()
          | :duplicate_token
          | :invalid_json_format
          | :invalid_tx_type

  @doc """
  Parses and validates json encoded fee specifications response
  Parses provided json string to token-fee map and returns the map together with possible parsing errors
  """
  @spec parse(binary() | map() | list()) ::
          {:ok, Engine.Fee.full_fee_t()}
          | {:error, list({:error, parsing_error(), any(), non_neg_integer() | nil})}
  def parse(fee_spec_json) when is_binary(fee_spec_json) do
    case Jason.decode(fee_spec_json) do
      {:ok, json} -> parse(json)
      error -> error
    end
  end

  def parse(json) when is_map(json) do
    {errors, fee_specs} = Enum.reduce(json, {[], %{}}, &reduce_json/2)

    errors
    |> Enum.reverse()
    |> (&{&1, fee_specs}).()
    |> handle_parser_output()
  end

  defp reduce_json({tx_type, fee_spec}, {all_errors, fee_specs}) do
    tx_type
    |> Integer.parse()
    |> parse_for_type(fee_spec)
    |> handle_type_parsing_output(tx_type, all_errors, fee_specs)
  end

  defp reduce_json(_, {all_errors, fee_specs}) do
    {[{:error, :invalid_json_format, nil, nil} | all_errors], fee_specs}
  end

  defp parse_for_type({tx_type, ""}, fee_spec) do
    fee_spec
    |> Enum.map(&SingleSpecParser.parse/1)
    |> Enum.reduce({[], %{}, 1, tx_type}, &spec_reducer/2)
  end

  defp parse_for_type(_, _), do: {:error, :invalid_tx_type}

  defp handle_type_parsing_output({:error, :invalid_tx_type} = error, tx_type, all_errors, fee_specs) do
    e =
      error
      |> Tuple.append(tx_type)
      |> Tuple.append(0)

    {[e | all_errors], fee_specs}
  end

  defp handle_type_parsing_output({errors, token_fee_map, _, tx_type}, _, all_errors, fee_specs) do
    {errors ++ all_errors, Map.put(fee_specs, tx_type, token_fee_map)}
  end

  defp spec_reducer({:error, reason}, {errors, token_fee_map, spec_index, tx_type}) do
    # most errors can be detected parsing particular record
    {[{:error, reason, tx_type, spec_index} | errors], token_fee_map, spec_index + 1, tx_type}
  end

  defp spec_reducer({:ok, token_fee}, {errors, token_fee_map, spec_index, tx_type}) do
    %{token: token} = token_fee
    token_fee = Map.drop(token_fee, [:token])
    # checks whether token was specified before
    if Map.has_key?(token_fee_map, token),
      do: {[{:error, :duplicate_token, tx_type, spec_index} | errors], token_fee_map, spec_index + 1, tx_type},
      else: {errors, Map.put(token_fee_map, token, token_fee), spec_index + 1, tx_type}
  end

  defp handle_parser_output({[], fee_specs}) do
    _ = Logger.debug("Parsing fee specification file completes successfully.")
    {:ok, fee_specs}
  end

  defp handle_parser_output({[{:error, _error, _tx_type, _index} | _] = errors, _fee_specs}) do
    _ = Logger.warn("Parsing fee specification file fails with errors:")

    Enum.each(errors, fn {:error, reason, tx_type, index} ->
      _ =
        Logger.warn(
          " * ##{inspect(index)} for transaction type ##{inspect(tx_type)} fee spec parser failed with error: #{
            inspect(reason)
          }"
        )
    end)

    {:error, errors}
  end
end
