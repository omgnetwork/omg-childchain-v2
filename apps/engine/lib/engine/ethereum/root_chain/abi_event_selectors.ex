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
      input_names: ["owner", "exitId"],
      inputs_indexed: [true, false],
      method_id: <<221, 111, 117, 92>>,
      returns: [],
      type: :event,
      types: [:address, {:uint, 160}]
    }
  end

  @spec in_flight_exit_started() :: ABI.FunctionSelector.t()
  def in_flight_exit_started() do
    %ABI.FunctionSelector{
      function: "InFlightExitStarted",
      input_names: ["initiator", "txHash"],
      inputs_indexed: [true, true],
      method_id: <<213, 241, 254, 157>>,
      returns: [],
      type: :event,
      types: [:address, {:bytes, 32}]
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
      input_names: ["exitTarget", "txHash", "inputIndex"],
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
      input_names: ["exitTarget", "txHash", "outputIndex"],
      inputs_indexed: [true, true, false],
      method_id: <<110, 205, 142, 121>>,
      returns: [],
      type: :event,
      types: [:address, {:bytes, 32}, {:uint, 16}]
    }
  end
end
