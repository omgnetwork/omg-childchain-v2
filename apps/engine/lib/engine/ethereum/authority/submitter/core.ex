defmodule Engine.Ethereum.Authority.Submitter.Core do
  @moduledoc false

  #  alias Engine.DB.Block

  def adjust_gas_and_submit(blocks) do
    :ok =
      Enum.each(
        blocks,
        fn block ->
          spawn(External, :submit_block, [block])
        end
      )
  end
end
