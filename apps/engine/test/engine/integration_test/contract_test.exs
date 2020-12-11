defmodule ContractTest do
  use Engine.DB.DataCase, async: false

  alias Engine.Configuration
  alias Engine.DB.ContractsConfig
  alias Engine.Geth
  alias Engine.ReleaseTasks.Contract
  alias Engine.ReleaseTasks.Contract.EIP55

  @moduletag :integration

  setup_all do
    {:ok, _briefly} = Application.ensure_all_started(:briefly)
    port = Enum.random(35_000..40_000)
    {:ok, {geth_pid, _container_id}} = Geth.start(port)

    System.put_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK", Configuration.plasma_framework())
    System.put_env("AUTHORITY_ADDRESS", Configuration.authority_address())
    System.put_env("TX_HASH_CONTRACT", Configuration.tx_hash_contract())
    System.put_env("ETHEREUM_RPC_URL", "http://localhost:#{port}")

    on_exit(fn ->
      GenServer.stop(geth_pid)
    end)

    %{port: port}
  end

  describe "on_load/2" do
    test "contracts data is fetched from the blockchain and stored in the database", %{port: port} do
      engine_setup = [
        ethereumex: [url: "not used because env var"],
        engine: [
          rpc_url: "http://localhost:#{port}",
          authority_address: Configuration.authority_address(),
          plasma_framework: Configuration.plasma_framework(),
          eth_vault: EIP55.encode!(Configuration.eth_vault()),
          erc20_vault: EIP55.encode!(Configuration.erc20_vault()),
          payment_exit_game: EIP55.encode!(Configuration.payment_exit_game()),
          min_exit_period_seconds: 20,
          contract_semver: "UPDATED",
          child_block_interval: 1000,
          contract_deployment_height: "UPDATED"
        ]
      ]

      config = Contract.load([{:ethereumex, [url: "not used because env var"]}], [])
      # update contract deployment height
      contract_deployment_height = config |> Keyword.get(:engine) |> Keyword.get(:contract_deployment_height)

      engine_setup2 =
        Keyword.update!(engine_setup, :engine, fn existing_value ->
          Keyword.merge(existing_value, contract_deployment_height: contract_deployment_height)
        end)

      # update contract semver
      semver = config |> Keyword.get(:engine) |> Keyword.get(:contract_semver)

      engine_setup3 =
        Keyword.update!(engine_setup2, :engine, fn existing_value ->
          Keyword.merge(existing_value, contract_semver: semver)
        end)

      assert config |> Keyword.get(:engine) |> Enum.sort() ==
               engine_setup3 |> Keyword.get(:engine) |> Enum.sort()

      # config is stored in database
      contracts_config = ContractsConfig.get(Repo)

      assert contracts_config == [
               payment_exit_game: EIP55.encode!(Configuration.payment_exit_game()),
               eth_vault: EIP55.encode!(Configuration.eth_vault()),
               erc20_vault: EIP55.encode!(Configuration.erc20_vault()),
               min_exit_period_seconds: 20,
               contract_semver: semver,
               child_block_interval: 1000,
               contract_deployment_height: contract_deployment_height
             ]
    end

    test "contract data is fetched from the db", %{port: port} do
      config_in_db = %{
        eth_vault: "eth_from_db",
        erc20_vault: "erc_from_db",
        payment_exit_game: "payment_exit_game",
        min_exit_period_seconds: 20,
        contract_semver: "2.0.0+ddbd40b",
        child_block_interval: 1000,
        contract_deployment_height: 120
      }

      {:ok, _} = ContractsConfig.insert(Repo, config_in_db)

      expected = [
        ethereumex: [url: "not used because env var"],
        engine: [
          rpc_url: "http://localhost:#{port}",
          authority_address: Configuration.authority_address(),
          plasma_framework: Configuration.plasma_framework(),
          payment_exit_game: Map.get(config_in_db, :payment_exit_game),
          eth_vault: Map.get(config_in_db, :eth_vault),
          erc20_vault: Map.get(config_in_db, :erc20_vault),
          min_exit_period_seconds: Map.get(config_in_db, :min_exit_period_seconds),
          contract_semver: Map.get(config_in_db, :contract_semver),
          child_block_interval: Map.get(config_in_db, :child_block_interval),
          contract_deployment_height: Map.get(config_in_db, :contract_deployment_height)
        ]
      ]

      actual = Contract.load([{:ethereumex, [url: "not used because env var"]}], [])
      assert actual == expected
    end
  end
end
