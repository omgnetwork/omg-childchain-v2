defmodule Engine.Ethereum.Event.Aggregator.Storage do
  @moduledoc """
    Storage interaction for Ethereum aggregator
  """

  alias Engine.Ethereum.Event.Aggregator.Storage.Write
  alias Engine.Ethereum.RootChain.Abi
  alias ExPlasma.Encoding

  require Logger

  # delete everything older then (current block - delete_events_threshold)
  def delete_old_logs(new_height_blknum, state) do
    # :ets.fun2ms(fn {block_number, _event_signature, _event} when
    # block_number <= new_height - delete_events_threshold -> true end)
    match_spec = [
      {{:"$1", :"$2", :"$3"},
       [{:"=<", :"$1", {:-, {:const, new_height_blknum}, {:const, state.delete_events_threshold_height_blknum}}}],
       [true]}
    ]

    :ets.select_delete(state.ets_bucket, match_spec)
  end

  # allow ethereum event listeners to retrieve logs from ETS in bulk
  def retrieve_log(signature, from_block, to_block, state) do
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

    events = state.ets_bucket |> :ets.select(event_match_spec) |> List.flatten()
    blknum_list = :ets.select(state.ets_bucket, block_range)

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

  defp retrieve_and_store_logs(from_block, to_block, state) do
    from_block
    |> get_logs(to_block, state)
    |> enrich_logs_with_call_data(state)
    |> Write.logs(from_block, to_block, state)
  end

  defp get_logs(from_height, to_height, state) do
    {:ok, logs} =
      state.event_interface.get_ethereum_events(
        from_height,
        to_height,
        state.event_signatures,
        state.contracts,
        state.opts
      )

    Enum.map(logs, &Abi.decode_log(&1))
  end

  # we get the logs from RPC and we cross check with the event definition if we need to enrich them
  defp enrich_logs_with_call_data(decoded_logs, state) do
    events = state.events

    Enum.map(decoded_logs, fn decoded_log ->
      decoded_log_signature = decoded_log.event_signature

      event = Enum.find(events, fn event -> Keyword.fetch!(event, :signature) == decoded_log_signature end)

      case Keyword.fetch!(event, :enrich) do
        true ->
          {:ok, enriched_data} = state.event_interface.get_call_data(decoded_log.root_chain_tx_hash)

          enriched_data_decoded = enriched_data |> Encoding.to_binary() |> Abi.decode_function()
          Map.put(decoded_log, :call_data, enriched_data_decoded)

        _ ->
          decoded_log
      end
    end)
  end
end
