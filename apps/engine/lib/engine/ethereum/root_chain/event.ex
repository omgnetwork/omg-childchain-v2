defmodule Engine.Ethereum.RootChain.Event do
  @moduledoc """
  Parse signatures from Event definitions so that we're able to create eth_getLogs topics.
  Preprocess event requests.
  """
  alias Engine.Ethereum.RootChain.AbiEventSelector
  alias Engine.Ethereum.RootChain.Rpc
  alias ExPlasma.Encoding

  @doc """
  Event preprocessing and fetching from RPC
  """
  def get_ethereum_events(block_from, block_to, [_ | _] = signatures, [_ | _] = contracts, opts) do
    topics = Enum.map(signatures, fn signature -> event_topic_for_signature(signature) end)

    topics_and_signatures =
      Enum.reduce(Enum.zip(topics, signatures), %{}, fn {topic, signature}, acc -> Map.put(acc, topic, signature) end)

    contracts = Enum.map(contracts, &Encoding.to_hex(&1))
    block_from = Encoding.to_hex(block_from)
    block_to = Encoding.to_hex(block_to)

    params = %{
      fromBlock: block_from,
      toBlock: block_to,
      address: contracts,
      topics: [topics]
    }

    {:ok, logs} = Rpc.eth_get_logs(params, opts)
    filtered_and_enriched_logs = handle_result(logs, topics, topics_and_signatures)
    {:ok, filtered_and_enriched_logs}
  end

  def get_ethereum_events(block_from, block_to, [_ | _] = signatures, contract, opts) do
    get_ethereum_events(block_from, block_to, signatures, [contract], opts)
  end

  def get_ethereum_events(block_from, block_to, signature, [_ | _] = contracts, opts) do
    get_ethereum_events(block_from, block_to, [signature], contracts, opts)
  end

  def get_ethereum_events(block_from, block_to, signature, contract, opts) do
    get_ethereum_events(block_from, block_to, [signature], [contract], opts)
  end

  @doc """
  Event definition via event selectors in ABI
  """
  @spec get_events(list(atom())) :: list(binary())
  def get_events(wanted_events) do
    events = events()

    wanted_events
    |> Enum.reduce([], fn wanted_event_name, acc ->
      get_event(events, wanted_event_name, acc)
    end)
    |> Enum.reverse()
  end

  defp event_topic_for_signature(signature) do
    signature
    |> ExthCrypto.Hash.hash(ExthCrypto.Hash.kec())
    |> Encoding.to_hex()
  end

  defp handle_result(logs, topics, topics_and_signatures) do
    acc = []
    handle_result(logs, topics, topics_and_signatures, acc)
  end

  defp handle_result([], _topics, _topics_and_signatures, acc), do: acc

  defp handle_result([%{"removed" => true} | _logs], _topics, _topics_and_signatures, acc) do
    acc
  end

  defp handle_result([log | logs], topics, topics_and_signatures, acc) do
    topic = Enum.find(topics, fn topic -> Enum.at(log["topics"], 0) == topic end)
    enriched_log = put_signature(log, Map.get(topics_and_signatures, topic))
    handle_result(logs, topics, topics_and_signatures, [enriched_log | acc])
  end

  defp put_signature(log, signature), do: Map.put(log, :event_signature, signature)

  # Event definition via event selectors in ABI
  # pull all exported functions out the AbiEventSelector module
  # and create an event signature
  # function_name(arguments)
  @spec events() :: list({atom(), binary()})
  defp events() do
    Enum.reduce(AbiEventSelector.module_info(:exports), [], fn
      {:module_info, 0}, acc -> acc
      {function, 0}, acc -> [{function, describe_event(apply(AbiEventSelector, function, []))} | acc]
      _, acc -> acc
    end)
  end

  defp describe_event(selector) do
    "#{selector.function}(" <> build_types_string(selector.types) <> ")"
  end

  defp build_types_string(types), do: build_types_string(types, "")
  defp build_types_string([], string), do: string

  defp build_types_string([{type, size} | [] = types], string) do
    build_types_string(types, string <> "#{type}" <> "#{size}")
  end

  defp build_types_string([{type, size} | types], string) do
    build_types_string(types, string <> "#{type}" <> "#{size}" <> ",")
  end

  defp build_types_string([type | [] = types], string) do
    build_types_string(types, string <> "#{type}")
  end

  defp build_types_string([type | types], string) do
    build_types_string(types, string <> "#{type}" <> ",")
  end

  def get_event(events, wanted_event_name, acc) do
    case Enum.find(events, fn {function_name, _signature} -> function_name == wanted_event_name end) do
      nil -> acc
      {_, signature} -> [signature | acc]
    end
  end
end
