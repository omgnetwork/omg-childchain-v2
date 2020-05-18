defmodule Engine.Ethereum.Authority.Submitter.Gas.Adjustment do
  @moduledoc """
  Encapsulates the Ethereum gas price adjustment strategy parameters into its own structure
  """

  defstruct eth_gap_without_child_blocks: 2,
            gas_price_lowering_factor: 0.9,
            gas_price_raising_factor: 2.0,
            max_gas_price: 20_000_000_000,
            last_block_mined: nil

  @type t() :: %__MODULE__{
          # minimum blocks count where child blocks are not mined therefore gas price needs to be increased
          eth_gap_without_child_blocks: pos_integer(),
          # the factor the gas price will be decreased by
          gas_price_lowering_factor: float(),
          # the factor the gas price will be increased by
          gas_price_raising_factor: float(),
          # maximum gas price above which raising has no effect, limits the gas price calculation
          max_gas_price: pos_integer(),
          # remembers ethereum height and last child block mined, used for the gas price calculation
          last_block_mined: tuple() | nil
        }
end
