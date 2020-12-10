defmodule ContractTest do
  use Engine.DB.DataCase, async: false

  alias Engine.Configuration
  alias Engine.DB.ContractsConfig
  alias Engine.Geth
  alias Engine.ReleaseTasks.Contract

  @moduletag :integration

  setup_all do
    {:ok, _briefly} = Application.ensure_all_started(:briefly)
    port = Enum.random(35_000..40_000)
    {:ok, {_geth_pid, _container_id}} = Geth.start(port)

    System.put_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK", Configuration.plasma_framework())
    System.put_env("AUTHORITY_ADDRESS", Configuration.authority_address())
    System.put_env("TX_HASH_CONTRACT", Configuration.tx_hash_contract())
    System.put_env("ETHEREUM_RPC_URL", "http://localhost:#{port}")

    %{port: port}
  end

  describe "on_load/2" do
    test "contracts are fetched from the blockchain and stored in the database", %{port: port} do
      engine_setup = [
        ethereumex: [url: "not used because env var"],
        engine: [
          rpc_url: "http://localhost:#{port}",
          authority_address: "0xf91d00cc5906c355b6c8a04d9d940c4adc64cb1c",
          plasma_framework: "0x97ba80836092c734d400acb79e310bcd4776dddb",
          eth_vault: "0xf39aba0a60dd1be8f9ddf2cc2104e8c3a8ba5670",
          erc20_vault: "0xe520b5e3df580f9015141152e152ea5edf119a74",
          payment_exit_game: "0xdd2860dd8f182f90870383a98ddaf63fdb00573e",
          min_exit_period_seconds: 20,
          contract_semver: "2.0.0+ddbd40b",
          child_block_interval: 1000,
          contract_deployment_height: 120
        ]
      ]

      config = Contract.load([{:ethereumex, [url: "not used because env var"]}], [])
      assert engine_setup == config
    end

    test "contract data is fetched from the db", %{port: port} do
      params = %{
        eth_vault: "eth_from_db",
        erc20_vault: "erc_from_db",
        payment_exit_game: "payment_exit_game",
        min_exit_period_seconds: 20,
        contract_semver: "2.0.0+ddbd40b",
        child_block_interval: 1000,
        contract_deployment_height: 120
      }

      {:ok, _} = ContractsConfig.insert(Engine.Repo, params)

      engine_setup = [
        ethereumex: [url: "not used because env var"],
        engine: [
          rpc_url: "http://localhost:#{port}",
          authority_address: "0xf91d00cc5906c355b6c8a04d9d940c4adc64cb1c",
          plasma_framework: "0x97ba80836092c734d400acb79e310bcd4776dddb",
          eth_vault: "eth_from_db",
          erc20_vault: "erc_from_db",
          payment_exit_game: "payment_exit_game",
          min_exit_period_seconds: 20,
          contract_semver: "2.0.0+ddbd40b",
          child_block_interval: 1000,
          contract_deployment_height: 120
        ]
      ]

      config = Contract.load([{:ethereumex, [url: "not used because env var"]}], [])
      assert engine_setup == config
    end
  end
end
