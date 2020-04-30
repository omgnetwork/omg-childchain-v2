defmodule Engine.Ethereum.RootChain.Fields do
  @moduledoc """
  Adapt to naming from contracts to elixir-omg.

  I need to do this even though I'm bleeding out of my eyes.
  """

  def rename(data, %ABI.FunctionSelector{function: "startInFlightExit"}) do
    contracts_naming = [
      {"inFlightTx", :in_flight_tx},
      {"inputTxs", :input_txs},
      {"inputUtxosPos", :input_utxos_pos},
      {"inputTxsInclusionProofs", :input_inclusion_proofs},
      {"inFlightTxWitnesses", :in_flight_tx_sigs}
    ]

    reduce_naming(data, contracts_naming)
  end

  def rename(data, %ABI.FunctionSelector{function: "startStandardExit"}) do
    contracts_naming = [
      {"outputTxInclusionProof", :output_tx_inclusion_proof},
      {"rlpOutputTx", :output_tx},
      {"utxoPos", :utxo_pos}
    ]

    # not used and discarded
    Map.delete(reduce_naming(data, contracts_naming), :output_tx_inclusion_proof)
  end

  defp reduce_naming(data, contracts_naming) do
    Enum.reduce(contracts_naming, %{}, fn
      {old_name, new_name}, acc ->
        value = Map.get(data, old_name)

        acc
        |> Map.put_new(new_name, value)
        |> Map.delete(old_name)
    end)
  end
end
