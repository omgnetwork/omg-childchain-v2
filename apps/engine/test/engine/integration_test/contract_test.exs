defmodule ContractTest do
  use ExUnit.Case, async: true

  alias Engine.Configuration
  alias Engine.Geth
  alias Engine.ReleaseTasks.Contract

  @moduletag :integration

  setup_all do
    {:ok, _briefly} = Application.ensure_all_started(:briefly)
    port = Enum.random(35_000..40_000)
    {:ok, {_geth_pid, _container_id}} = Geth.start(port)
    %{port: port}
  end

  describe "on_load/2" do
    test "contracts are fetched from the blockchain", %{port: port} do
      System.put_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK", Configuration.plasma_framework())
      System.put_env("AUTHORITY_ADDRESS", Configuration.authority_address())
      System.put_env("TX_HASH_CONTRACT", Configuration.tx_hash_contract())
      System.put_env("ETHEREUM_RPC_URL", "http://localhost:#{port}")

      engine_setup = [
        ethereumex: [url: "not used because env var"],
        engine: [
          rpc_url: "http://localhost:#{port}",
          authority_address: "0x1ab323bcd956992806594faa72e5ed41509a9662",
          plasma_framework: "0x97ba80836092c734d400acb79e310bcd4776dddb",
          eth_vault: "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
          erc20_vault: "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
          payment_exit_game: "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
          min_exit_period_seconds: 20,
          contract_semver: "2.0.0+8468675",
          child_block_interval: 1000,
          contract_deployment_height: 131
        ]
      ]

      config = Contract.load([{:ethereumex, [url: "not used because env var"]}], [])
      assert engine_setup == config
    end
  end
end
