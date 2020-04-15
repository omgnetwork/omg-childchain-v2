defmodule Engine.ReleaseTasks.Contract.ExternalTest do
  use ExUnit.Case, async: true

  alias DBConnection.Backoff
  alias Engine.ReleaseTasks.Contract.External

  describe "min_exit_period/1" do
    test "that the returned data is a number", %{test: test_name} do
      defmodule test_name do
        def call_contract(_, _, _) do
          {:ok, "0x0000000000000000000000000000000000000000000000000000000000000014"}
        end
      end

      Process.put(:rpc_api, test_name)
      min_exit_period = External.min_exit_period("contract address")
      assert min_exit_period == 20
    end
  end

  describe "exit_game_contract_address/2" do
    test "that the returned data is an address", %{test: test_name} do
      defmodule test_name do
        def call_contract(_, _, _) do
          {:ok, "0x00000000000000000000000089afce326e7da55647d22e24336c6a2816c99f6b"}
        end
      end

      Process.put(:rpc_api, test_name)
      exit_game_contract_address = External.exit_game_contract_address("contract address", 1)
      assert exit_game_contract_address == "0x89afce326e7da55647d22e24336c6a2816c99f6b"
    end
  end

  describe "vault/2" do
    test "that the returned data is an address", %{test: test_name} do
      defmodule test_name do
        def call_contract(_, _, _) do
          {:ok, "0x00000000000000000000000089afce326e7da55647d22e24336c6a2816c99f6b"}
        end
      end

      Process.put(:rpc_api, test_name)
      vault_address = External.vault("contract address", 1)
      assert vault_address == "0x89afce326e7da55647d22e24336c6a2816c99f6b"
    end
  end

  describe "contract_semver/1" do
    test "that the returned data is a semver", %{test: test_name} do
      defmodule test_name do
        def call_contract(_, _, _) do
          {:ok,
           "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000d312e302e342b6136396337363300000000000000000000000000000000000000"}
        end
      end

      Process.put(:rpc_api, test_name)
      contract_semver = External.contract_semver("contract address")
      assert contract_semver == "1.0.4+a69c763"
      version = Version.parse!(contract_semver)
      assert version.major == 1
      assert version.minor == 0
      assert version.patch == 4
      assert version.build == "a69c763"
    end
  end

  describe "childBlockInterval/1" do
    test "that the returned data is an integer", %{test: test_name} do
      defmodule test_name do
        def call_contract(_, _, _) do
          {:ok, "0x00000000000000000000000000000000000000000000000000000000000003e8"}
        end
      end

      Process.put(:rpc_api, test_name)
      child_block_interval = External.child_block_interval("contract address")
      assert child_block_interval == 1000
    end
  end

  describe "call/4" do
    test "if the client closes the connection we retry - :closed", %{test: test_name} do
      Agent.start_link(fn -> 0 end, name: test_name)

      defmodule test_name do
        def call_contract(_, _, _) do
          case Agent.get_and_update(__MODULE__, fn state -> {state, state + 1} end) do
            0 -> {:error, :closed}
            1 -> {:ok, "0x0000000000000000000000000000000000000000000000000000000000000014"}
          end
        end
      end

      Process.put(:rpc_api, test_name)
      min_exit_period = External.min_exit_period("contract address")
      assert min_exit_period == 20
    end

    test "if client is not ready yet we backoff and wait - :econnrefused", %{test: test_name} do
      Agent.start_link(fn -> 0 end, name: test_name)

      defmodule test_name do
        def call_contract(_, _, _) do
          case Agent.get_and_update(__MODULE__, fn state -> {state, state + 1} end) do
            2 -> {:ok, "0x0000000000000000000000000000000000000000000000000000000000000014"}
            _ -> {:error, :econnrefused}
          end
        end
      end

      backoff = Backoff.new(backoff_min: 1, backoff_max: 10)
      Process.put(:backoff, backoff)
      Process.put(:rpc_api, test_name)
      min_exit_period = External.min_exit_period("contract address")
      assert min_exit_period == 20
      refute Process.get(:backoff) == backoff
    end
  end
end
