defmodule Engine.Ethereum.Authority.Submitter.Gas do
  @moduledoc """
    Gas price selection

      # The mechanism employed is minimalistic, aiming at:
      #   - pushing formed block submissions as reliably as possible, avoiding delayed mining of submissions as much as possible
      #   - saving Ether only when certain that we're overpaying
      #   - being simple and avoiding any external factors driving the mechanism
  """
end

# Calculates the gas price basing on simple strategy to raise the gas price by gas_price_raising_factor
# when gap of mined parent blocks is growing and droping the price by gas_price_lowering_factor otherwise
# @spec calculate_gas_price(Core.t()) :: pos_integer()
# defp calculate_gas_price(%Core{
#        formed_child_block_num: formed_child_block_num,
#        mined_child_block_num: mined_child_block_num,
#        gas_price_to_use: gas_price_to_use,
#        parent_height: parent_height,
#        gas_price_adj_params: %GasPriceAdjustment{
#          gas_price_lowering_factor: gas_price_lowering_factor,
#          gas_price_raising_factor: gas_price_raising_factor,
#          eth_gap_without_child_blocks: eth_gap_without_child_blocks,
#          max_gas_price: max_gas_price,
#          last_block_mined: {lastchecked_parent_height, lastchecked_mined_block_num}
#        }
#      }) do
#   multiplier =
#     with true <- blocks_needs_be_mined?(formed_child_block_num, mined_child_block_num),
#          true <- eth_blocks_gap_filled?(parent_height, lastchecked_parent_height, eth_gap_without_child_blocks),
#          false <- new_blocks_mined?(mined_child_block_num, lastchecked_mined_block_num) do
#       gas_price_raising_factor
#     else
#       _ -> gas_price_lowering_factor
#     end

#   Kernel.min(
#     max_gas_price,
#     Kernel.round(multiplier * gas_price_to_use)
#   )
# end
