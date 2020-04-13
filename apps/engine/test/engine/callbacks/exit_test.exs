defmodule Engine.Callbacks.ExitTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Engine.Factory
  import Ecto.Query

  alias Engine.Callbacks.Exit

  describe "callback/1" do
    test "marks utxos that are exiting" do
      utxo = insert(:input_utxo, pos: 1)

      exit_events = [
        %{
          call_data: %{
            output_tx: <<0>>,
            utxo_pos: utxo.pos
          },
          eth_height: 1676,
          event_signature: "ExitStarted(address,uint160)",
          exit_id: 2_812_721_707_145_513_089_028_719_506_236_303_203_225_368,
          log_index: 1,
          owner: <<43, 240, 242, 172, 73, 83, 240, 173, 228, 58, 95, 61, 91, 148, 170, 3, 238, 172, 173, 157>>,
          root_chain_txhash:
            <<22, 115, 252, 106, 26, 193, 50, 43, 145, 150, 64, 164, 140, 100, 3, 4, 45, 193, 97, 40, 231, 41, 105, 130,
              118, 28, 128, 196, 88, 132, 207, 163>>
        }
      ]

      assert {1, nil} = Exit.callback(exit_events)

      query = from(u in Engine.Utxo, where: u.pos == ^utxo.pos, select: u.state)

      assert "exited" = Engine.Repo.one(query)
    end

    test "marks multiple utxos as exiting" do
      utxo = insert(:input_utxo, pos: 2)
      utxo2 = insert(:input_utxo, pos: 3)

      exit_events = [
        %{
          call_data: %{
            output_tx: <<0>>,
            utxo_pos: utxo.pos
          },
          eth_height: 1676,
          event_signature: "ExitStarted(address,uint160)",
          exit_id: 2_812_721_707_145_513_089_028_719_506_236_303_203_225_368,
          log_index: 1,
          owner: <<43, 240, 242, 172, 73, 83, 240, 173, 228, 58, 95, 61, 91, 148, 170, 3, 238, 172, 173, 157>>,
          root_chain_txhash:
            <<22, 115, 252, 106, 26, 193, 50, 43, 145, 150, 64, 164, 140, 100, 3, 4, 45, 193, 97, 40, 231, 41, 105, 130,
              118, 28, 128, 196, 88, 132, 207, 163>>
        },
        %{
          call_data: %{
            output_tx: <<0>>,
            utxo_pos: utxo2.pos
          },
          eth_height: 1676,
          event_signature: "ExitStarted(address,uint160)",
          exit_id: 2_812_721_707_145_513_089_028_719_506_236_303_203_225_368,
          log_index: 1,
          owner: <<43, 240, 242, 172, 73, 83, 240, 173, 228, 58, 95, 61, 91, 148, 170, 3, 238, 172, 173, 157>>,
          root_chain_txhash:
            <<22, 115, 252, 106, 26, 193, 50, 43, 145, 150, 64, 164, 140, 100, 3, 4, 45, 193, 97, 40, 231, 41, 105, 130,
              118, 28, 128, 196, 88, 132, 207, 163>>
        }
      ]

      assert {2, nil} = Exit.callback(exit_events)

      query = from(u in Engine.Utxo, where: u.pos in [^utxo.pos, ^utxo2.pos], select: u.state)

      assert ["exited", "exited"] = Engine.Repo.all(query)
    end
  end
end
