defmodule Engine.Ethereum.RootChain.Abi do
  @moduledoc """
  Functions that provide ethereum log decoding
  """
  alias Engine.Ethereum.RootChain.AbiEventSelector
  alias Engine.Ethereum.RootChain.AbiFunctionSelector
  alias Engine.Ethereum.RootChain.Event
  alias Engine.Ethereum.RootChain.Fields
  alias ExPlasma.Crypto
  alias ExPlasma.Encoding

  def decode_function(enriched_data, signature) do
    "0x" <> data = enriched_data
    <<method_id::binary-size(4), _::binary>> = Crypto.keccak_hash(signature)
    method_id |> Encoding.to_hex() |> Kernel.<>(data) |> Encoding.to_binary!() |> decode_function()
  end

  def decode_function(enriched_data) do
    function_specs =
      Enum.reduce(AbiFunctionSelector.module_info(:exports), [], fn
        {:module_info, 0}, acc -> acc
        {function, 0}, acc -> [apply(AbiFunctionSelector, function, []) | acc]
        _, acc -> acc
      end)

    {function_spec, data} = ABI.find_and_decode(function_specs, enriched_data)
    decode_function_call_result(function_spec, data)
  end

  @spec decode_log(map(), map()) :: Event.t()
  def decode_log(log, keccak_signatures_pair) do
    event_specs =
      Enum.reduce(AbiEventSelector.module_info(:exports), [], fn
        {:module_info, 0}, acc -> acc
        {function, 0}, acc -> [apply(AbiEventSelector, function, []) | acc]
        _, acc -> acc
      end)

    topics =
      Enum.map(log["topics"], fn
        nil -> nil
        topic -> Encoding.to_binary!(topic)
      end)

    {_event_spec, data} =
      ABI.Event.find_and_decode(
        event_specs,
        Enum.at(topics, 0),
        Enum.at(topics, 1),
        Enum.at(topics, 2),
        Enum.at(topics, 3),
        Encoding.to_binary!(log["data"])
      )

    data
    |> Enum.into(%{}, fn {key, _type, _indexed, value} -> {key, value} end)
    |> common_parse_event(log, keccak_signatures_pair)
  end

  def common_parse_event(event, log, keccak_signatures_pair) do
    topic = log |> Map.get("topics") |> Enum.at(0)
    event_signature = Map.get(keccak_signatures_pair, topic)

    %Event{
      data: event,
      eth_height: Encoding.to_int(log["blockNumber"]),
      root_chain_tx_hash: Encoding.to_binary!(log["transactionHash"]),
      log_index: Encoding.to_int(log["logIndex"]),
      event_signature: event_signature
    }
  end

  defp decode_function_call_result(function_spec, [values]) when is_tuple(values) do
    function_spec.input_names
    |> Enum.zip(Tuple.to_list(values))
    |> Enum.into(%{})
    |> Fields.rename(function_spec)
  end

  defp decode_function_call_result(function_spec, values) do
    function_spec.input_names
    |> Enum.zip(Enum.map(values, &to_hex/1))
    |> Enum.into(%{})
  end

  defp to_hex(value) when is_binary(value) do
    case String.valid?(value) do
      false ->
        Encoding.to_hex(value)

      true ->
        value
    end
  end

  defp to_hex(value) do
    value
  end
end
