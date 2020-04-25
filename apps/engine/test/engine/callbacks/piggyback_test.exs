defmodule Engine.Callbacks.PiggybackTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Engine.DB.Factory
  import Ecto.Query

  alias Engine.Callbacks.Piggyback
  alias Engine.DB.Output

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Engine.Repo)
  end

  describe "callback/1" do
    test "marks an output as piggybacked" do
      owner = <<180, 121, 214, 88, 10, 185, 115, 237, 127, 113, 101, 78, 28, 82, 108, 57, 64, 154, 219, 241>>
      deposit = insert(:deposit_transaction, output_guard: owner)
      output = hd(deposit.outputs)

      event = %{
        eth_height: 495,
        event_signature: "InFlightExitOutputPiggybacked(address,bytes32,uint16)",
        log_index: 1,
        omg_data: %{piggyback_type: :output},
        output_index: 0,
        owner: owner,
        root_chain_txhash:
          <<212, 219, 104, 41, 4, 36, 0, 15, 174, 188, 194, 119, 144, 2, 194, 146, 29, 58, 74, 12, 131, 195, 142, 160,
            155, 40, 118, 247, 141, 135, 74, 138>>,
        tx_hash: deposit.txhash
      }

      key = "piggyback-output-#{output.position}"
      assert {:ok, %{ ^key => output}} = Piggyback.callback([event])
      assert output.state == "piggybacked"
    end
  end
end
