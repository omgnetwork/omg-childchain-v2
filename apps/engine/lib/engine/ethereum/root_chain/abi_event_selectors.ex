defmodule Engine.Ethereum.RootChain.AbiEventSelector do
  @moduledoc """
  We define Solidity Event selectors that help us decode returned values from function calls.
  Function names are to be used as inputs to Event Fetcher.
  Function names describe the type of the event Event Fetcher will retrieve.
  """

  @spec exit_started() :: ABI.FunctionSelector.t()
  def exit_started() do
    %ABI.FunctionSelector{
      function: "ExitStarted",
      input_names: ["owner", "exit_id", "utxo_pos", "output_tx"],
      inputs_indexed: [true, false, false, false],
      method_id: <<190, 31, 206, 232>>,
      returns: [],
      type: :event,
      types: [:address, {:uint, 168}, {:uint, 256}, :bytes]
    }
  end

  @spec in_flight_exit_started() :: ABI.FunctionSelector.t()
  def in_flight_exit_started() do
    %ABI.FunctionSelector{
      function: "InFlightExitStarted",
      input_names: ["initiator", "tx_hash", "in_flight_tx", "input_utxos_pos", "in_flight_tx_witnesses", "input_txs"],
      inputs_indexed: [true, true, false, false, false, false],
      method_id: <<150, 80, 84, 111>>,
      returns: [],
      type: :event,
      types: [
        :address,
        {:bytes, 32},
        :bytes,
        {:array, {:uint, 256}},
        {:array, :bytes},
        {:array, :bytes}
      ]
    }
  end

  @spec deposit_created() :: ABI.FunctionSelector.t()
  def deposit_created() do
    %ABI.FunctionSelector{
      function: "DepositCreated",
      input_names: ["depositor", "blknum", "token", "amount"],
      inputs_indexed: [true, true, true, false],
      method_id: <<24, 86, 145, 34>>,
      returns: [],
      type: :event,
      types: [:address, {:uint, 256}, :address, {:uint, 256}]
    }
  end

  @spec in_flight_exit_input_piggybacked() :: ABI.FunctionSelector.t()
  def in_flight_exit_input_piggybacked() do
    %ABI.FunctionSelector{
      function: "InFlightExitInputPiggybacked",
      input_names: ["exit_target", "tx_hash", "input_index"],
      inputs_indexed: [true, true, false],
      method_id: <<169, 60, 14, 155>>,
      returns: [],
      type: :event,
      types: [:address, {:bytes, 32}, {:uint, 16}]
    }
  end

  @spec in_flight_exit_output_piggybacked() :: ABI.FunctionSelector.t()
  def in_flight_exit_output_piggybacked() do
    %ABI.FunctionSelector{
      function: "InFlightExitOutputPiggybacked",
      input_names: ["exit_target", "tx_hash", "output_index"],
      inputs_indexed: [true, true, false],
      method_id: <<110, 205, 142, 121>>,
      returns: [],
      type: :event,
      types: [:address, {:bytes, 32}, {:uint, 16}]
    }
  end
end
