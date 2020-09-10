defmodule Engine.Ethereum.RootChain.Event do
  @moduledoc """
  Parse signatures from Event definitions so that we're able to create eth_getLogs topics.
  Preprocess event requests.
  """
  alias Engine.Ethereum.RootChain.AbiEventSelector
  alias Engine.Ethereum.RootChain.Rpc
  alias ExPlasma.Crypto
  alias ExPlasma.Encoding

  defstruct [:event_signature, :data, :call_data, :eth_height, :root_chain_tx_hash, :log_index]

  @type t() :: %__MODULE__{
          event_signature: binary(),
          log_index: non_neg_integer(),
          data: map(),
          call_data: map() | nil,
          eth_height: non_neg_integer(),
          root_chain_tx_hash: binary()
        }

  def event_topic_for_signature(signature) do
    signature
    |> Crypto.keccak_hash()
    |> Encoding.to_hex()
  end

  @doc """
  Event preprocessing and fetching from RPC
  """
  def get_ethereum_logs(block_from, block_to, [_ | _] = keccak_event_signatures, [_ | _] = contracts, opts) do
    topics = keccak_event_signatures
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
    {:ok, Enum.filter(logs, &filter_removed/1)}
  end

  def get_ethereum_logs(block_from, block_to, [_ | _] = keccak_event_signatures, contract, opts) do
    get_ethereum_logs(block_from, block_to, keccak_event_signatures, [contract], opts)
  end

  def get_ethereum_logs(block_from, block_to, keccak_event_signature, [_ | _] = contracts, opts) do
    get_ethereum_logs(block_from, block_to, [keccak_event_signature], contracts, opts)
  end

  def get_ethereum_logs(block_from, block_to, keccak_event_signature, contract, opts) do
    get_ethereum_logs(block_from, block_to, [keccak_event_signature], [contract], opts)
  end

  def get_call_data(root_chain_txhash) do
    {:ok, %{"input" => input}} =
      root_chain_txhash
      |> Encoding.to_hex()
      |> Rpc.transaction_by_hash([])

    {:ok, input}
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

  defp filter_removed(%{"removed" => true}), do: false
  defp filter_removed(_), do: true

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
