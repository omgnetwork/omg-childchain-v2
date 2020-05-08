defmodule Engine.Callbacks.ExitTest do
  @moduledoc false
  use Engine.DB.DataCase, async: true

  alias Engine.Callbacks.Exit
  alias Engine.DB.ListenerState
  alias Engine.DB.Output

  describe "callback/1" do
    test "marks utxos that are exiting" do
      %{outputs: [%{position: position}]} = insert(:deposit_transaction)

      exit_events = [
        %{
          call_data: %{
            "rlpOutputTx" => <<0>>,
            "utxoPos" => position
          },
          eth_height: 1676,
          event_signature: "ExitStarted(address,uint160)",
          exit_id: 2_812_721_707_145_513_089_028_719_506_236_303_203_225_368,
          log_index: 1,
          owner: <<43, 240, 242, 172, 73, 83, 240, 173, 228, 58, 95, 61, 91, 148, 170, 3, 238, 172, 173, 157>>,
          root_chain_tx_hash:
            <<22, 115, 252, 106, 26, 193, 50, 43, 145, 150, 64, 164, 140, 100, 3, 4, 45, 193, 97, 40, 231, 41, 105, 130,
              118, 28, 128, 196, 88, 132, 207, 163>>
        }
      ]

      assert {:ok, %{exiting_outputs: {1, nil}}} = Exit.callback(exit_events, :exit_started)

      assert %ListenerState{height: 1676, listener: "exit_started"} = Engine.Repo.get(ListenerState, "exit_started")

      query = from(o in Output, where: o.position == ^position, select: o.state)
      assert "exited" = Repo.one(query)
    end

    test "marks multiple utxos as exiting" do
      %{outputs: [%{position: pos1}]} = insert(:deposit_transaction)
      %{outputs: [%{position: pos2}]} = insert(:deposit_transaction)

      exit_events = [
        %{
          call_data: %{
           "rlpOutputTx" => <<0>>,
            "utxoPos" => pos1
          },
          eth_height: 1676,
          event_signature: "ExitStarted(address,uint160)",
          exit_id: 2_812_721_707_145_513_089_028_719_506_236_303_203_225_368,
          log_index: 1,
          owner: <<43, 240, 242, 172, 73, 83, 240, 173, 228, 58, 95, 61, 91, 148, 170, 3, 238, 172, 173, 157>>,
          root_chain_tx_hash:
            <<22, 115, 252, 106, 26, 193, 50, 43, 145, 150, 64, 164, 140, 100, 3, 4, 45, 193, 97, 40, 231, 41, 105, 130,
              118, 28, 128, 196, 88, 132, 207, 163>>
        },
        %{
          call_data: %{
            "rlpOutputTx" => <<0>>,
            "utxoPos" => pos2
          },
          eth_height: 1678,
          event_signature: "ExitStarted(address,uint160)",
          exit_id: 2_812_721_707_145_513_089_028_719_506_236_303_203_225_368,
          log_index: 1,
          owner: <<43, 240, 242, 172, 73, 83, 240, 173, 228, 58, 95, 61, 91, 148, 170, 3, 238, 172, 173, 157>>,
          root_chain_tx_hash:
            <<22, 115, 252, 106, 26, 193, 50, 43, 145, 150, 64, 164, 140, 100, 3, 4, 45, 193, 97, 40, 231, 41, 105, 130,
              118, 28, 128, 196, 88, 132, 207, 163>>
        }
      ]

      assert {:ok, %{exiting_outputs: {2, nil}}} = Exit.callback(exit_events, :exit_started)

      assert %ListenerState{height: 1678, listener: "exit_started"} = Engine.Repo.get(ListenerState, "exit_started")

      query = from(o in Output, where: o.position in [^pos1, ^pos2], select: o.state)
      assert ["exited", "exited"] = Repo.all(query)
    end
  end
end
