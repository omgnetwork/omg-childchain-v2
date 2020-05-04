defmodule Engine.Ethereum.Event.Aggregator.Storage.Write do
  @moduledoc """
    Storage commit for Ethereum aggregator
  """
  def logs(decoded_logs, from_block, to_block, state) do
    event_signatures = state.event_signatures

    # all logs come in a list of maps
    # we want to group them by blknum and signature:
    # [{286, "InFlightExitChallengeResponded(address,bytes32,uint256)", [event]},
    # {287, "ExitChallenged(uint256)",[event, event]]
    decoded_logs_in_keypair =
      decoded_logs
      |> Enum.group_by(
        fn decoded_log ->
          {decoded_log.eth_height, decoded_log.event_signature}
        end,
        fn decoded_log ->
          decoded_log
        end
      )
      |> Enum.map(fn {{blknum, signature}, logs} ->
        {blknum, signature, logs}
      end)

    # if we visited a particular range of blknum (from, to) we want to
    # insert empty data in the DB, so that clients know we've been there and that blocks are
    # empty of logs.
    # for the whole from, to range and signatures we create group pairs like so:
    # from = 286, to = 287 signatures = ["Exit", "Deposit"]
    # [{286, "Exit", []},{286, "Deposit", []},{287, "Exit", []},{287, "Deposit", []}]
    empty_blknum_signature_events =
      from_block..to_block
      |> Enum.to_list()
      |> Enum.map(fn blknum -> Enum.map(event_signatures, fn signature -> {blknum, signature, []} end) end)
      |> List.flatten()

    # we now merge the two lists
    # it is important that logs we got from RPC are first
    # because uniq_by takes the first occurance of {blknum, signature}
    # so that we don't overwrite retrieved logs
    data =
      decoded_logs_in_keypair
      |> Enum.concat(empty_blknum_signature_events)
      |> Enum.uniq_by(fn {blknum, signature, _data} ->
        {blknum, signature}
      end)

    true = :ets.insert(state.ets, data)
    :ok
  end
end
