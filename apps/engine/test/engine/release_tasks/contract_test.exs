defmodule Engine.ReleaseTasks.ContractTest do
  use ExUnit.Case, async: true

  alias __MODULE__.RpcApiMock
  alias __MODULE__.SystemMock

  describe "on_load/2" do
    test "plasma_framework, tx_hash and authority_address can be set" do
      Process.put(:rpc_api, RpcApiMock)

      engine_setup = [
        engine: [
          authority_address: "0xc673e4ffcb8464faff908a6804fe0e635af0ea2f",
          plasma_framework: "0xc673e4ffcb8464faff908a6804fe0e635af0ea2f",
          eth_vault: "0x00000000000000000000000000000000000003e8",
          erc20_vault: "0x00000000000000000000000000000000000003e8",
          payment_exit_game: "0x00000000000000000000000000000000000003e8",
          min_exit_period_seconds: 1000,
          contract_semver: "1.0.4+a69c763",
          child_block_interval: 1000,
          root_deployment_height: 1
        ]
      ]

      assert Engine.ReleaseTasks.Contract.load([], system_adapter: SystemMock) == engine_setup
    end
  end

  defmodule SystemMock do
    def get_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK") do
      "0xc673e4ffcb8464faff908a6804fe0e635af0ea2f"
    end

    def get_env("AUTHORITY_ADDRESS") do
      "0xc673e4ffcb8464faff908a6804fe0e635af0ea2f"
    end

    def get_env("TXHASH_CONTRACT") do
      "0xb836b6c4eb016e430b8e7495db92357896c1da263c6a3de73320b669eb5912d3"
    end

    def get_env("ETHEREUM_RPC_URL") do
      "localhost"
    end
  end

  defmodule RpcApiMock do
    def call_contract(_, "getVersion()", _) do
      data =
        "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000d312e302e342b6136396337363300000000000000000000000000000000000000"

      {:ok, data}
    end

    def call_contract(_, _, _) do
      data = "0x00000000000000000000000000000000000000000000000000000000000003e8"
      {:ok, data}
    end

    def transaction_receipt(_) do
      {:ok, %{"contractAddress" => "0xc673e4ffcb8464faff908a6804fe0e635af0ea2f", "blockNumber" => "0x1"}}
    end
  end
end
