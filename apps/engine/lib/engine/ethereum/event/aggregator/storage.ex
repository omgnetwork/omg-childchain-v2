defmodule Engine.Ethereum.Event.Aggregator.Storage do
  @moduledoc """
    Storage interaction for Ethereum aggregator
  """

  alias Engine.Ethereum.Event.Aggregator
  alias Engine.Ethereum.Event.Aggregator.Storage.Write
  alias Engine.Ethereum.RootChain.Abi
  alias Engine.Ethereum.RootChain.Event
  alias ExPlasma.Encoding

  require Logger

  @events_bucket :events_bucket

  @spec events_bucket(atom()) :: atom()
  def events_bucket(name \\ @events_bucket) do
    _ = if :undefined == :ets.info(name), do: :ets.new(name, [:bag, :public, :named_table])
    name
  end

  @doc "delete everything older then (current block - delete_events_threshold)"
  @spec delete_old_logs(non_neg_integer(), Aggregator.t()) :: non_neg_integer()
  def delete_old_logs(new_height_blknum, state) do
    ets = state.ets
    total_events = state.total_events
    # :ets.fun2ms(fn {block_number, _event_signature, _event} when
    # block_number <= new_height - delete_events_threshold -> true end)
    match_spec = [
      {{:"$1", :"$2", :"$3"}, [{:"=<", :"$1", {:-, {:const, new_height_blknum}, {:const, total_events}}}], [true]}
    ]

    :ets.select_delete(ets, match_spec)
  end

  @doc "allow ethereum event listeners to retrieve logs from ETS in bulk"
  @spec retrieve_log(list(String.t()), non_neg_integer(), non_neg_integer(), Aggregator.t()) :: list(Event.t())
  def retrieve_log(signature, from_block, to_block, state) do
    ets = state.ets
    # :ets.fun2ms(fn {block_number, event_signature, event} when
    # block_number >= from_block and block_number <= to_block
    # and event_signature == signature -> event
    # end)
    event_match_spec = [
      {{:"$1", :"$2", :"$3"},
       [
         {:andalso, {:andalso, {:>=, :"$1", {:const, from_block}}, {:"=<", :"$1", {:const, to_block}}},
          {:==, :"$2", {:const, signature}}}
       ], [:"$3"]}
    ]

    block_range = [
      {{:"$1", :"$2", :"$3"},
       [
         {:andalso, {:andalso, {:>=, :"$1", {:const, from_block}}, {:"=<", :"$1", {:const, to_block}}},
          {:==, :"$2", {:const, signature}}}
       ], [:"$1"]}
    ]

    events = ets |> :ets.select(event_match_spec) |> List.flatten()
    blknum_list = :ets.select(ets, block_range)

    # we may not have all the block information the ethereum event listener wants
    # so we check for that and find all logs for missing blocks
    # in one RPC call for all signatures
    case Enum.to_list(from_block..to_block) -- blknum_list do
      [] ->
        events

      missing_blocks ->
        missing_blocks = Enum.sort(missing_blocks)
        missing_from_block = List.first(missing_blocks)
        missing_to_block = List.last(missing_blocks)

        _ =
          Logger.debug(
            "Missing block information (#{missing_from_block}, #{missing_to_block}) in event fetcher. Additional RPC call to gather logs."
          )

        :ok = retrieve_and_store_logs(missing_from_block, missing_to_block, state)
        retrieve_log(signature, from_block, to_block, state)
    end
  end

  # raw data is logs which gets transformed into events
  @spec retrieve_and_store_logs(pos_integer(), pos_integer(), Aggregator.t()) :: :ok
  defp retrieve_and_store_logs(from_block, to_block, state) do
    from_block
    |> get_events(to_block, state)
    |> enrich_events_with_call_data(state)
    |> Write.logs(from_block, to_block, state)
  end

  @spec get_events(pos_integer(), pos_integer(), Aggregator.t()) :: list(Event.t())
  defp get_events(from_height, to_height, state) do
    {:ok, logs} =
      state.event_interface.get_ethereum_logs(
        from_height,
        to_height,
        state.keccak_event_signatures,
        state.contracts,
        state.opts
      )

    # we now return events!
    Enum.map(logs, &Abi.decode_log(&1, state.keccak_signatures_pair))
  end

  # we get the logs from RPC and we cross check with the event definition if we need to enrich them
  @spec enrich_events_with_call_data(list(Event.t()), Aggregator.t()) :: list(Event.t())
  defp enrich_events_with_call_data(decoded_events, state) do
    events = state.events

    Enum.map(decoded_events, fn decoded_event ->
      decoded_log_signature = decoded_event.event_signature

      event_definition = Enum.find(events, fn event -> Keyword.fetch!(event, :signature) == decoded_log_signature end)

      case Keyword.fetch!(event_definition, :enrich) do
        true ->
          {:ok, enriched_data} = state.event_interface.get_call_data(decoded_event.root_chain_tx_hash)

          enriched_data_decoded = enriched_data |> Encoding.to_binary!() |> Abi.decode_function()
          struct(decoded_event, call_data: enriched_data_decoded)

        _ ->
          decoded_event
      end
    end)
  end
end
