defmodule ContractTest do
  use ExUnit.Case, async: true

  alias Engine.Configuration
  alias Engine.Geth
  alias Engine.ReleaseTasks.Contract

  @moduletag :integration

  setup_all do
    {:ok, _briefly} = Application.ensure_all_started(:briefly)
    port = Enum.random(35_000..40_000)
    {:ok, {geth_pid, _container_id}} = Geth.start(port)

    on_exit(fn ->
      GenServer.stop(geth_pid)
    end)

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
          authority_address: Configuration.authority_address(),
          plasma_framework: Configuration.plasma_framework(),
          eth_vault: Configuration.eth_vault(),
          erc20_vault: Configuration.erc20_vault(),
          payment_exit_game: Configuration.payment_exit_game(),
          min_exit_period_seconds: 20,
          contract_semver: "UPDATED",
          child_block_interval: 1000,
          contract_deployment_height: "UPDATED"
        ]
      ]

      config = Contract.load([{:ethereumex, [url: "not used because env var"]}], [])
      # dear god this is abhorent
      # update contract deployment height
      engine_setup2 =
        Keyword.update!(engine_setup, :engine, fn existing_value ->
          Keyword.merge(existing_value,
            contract_deployment_height: Keyword.get(Keyword.get(config, :engine), :contract_deployment_height)
          )
        end)

      # update contract semver
      engine_setup3 =
        Keyword.update!(engine_setup2, :engine, fn existing_value ->
          Keyword.merge(existing_value,
            contract_semver: Keyword.get(Keyword.get(config, :engine), :contract_semver)
          )
        end)

      assert config |> Keyword.get(:engine) |> Enum.sort() == engine_setup3 |> Keyword.get(:engine) |> Enum.sort()
    end
  end
end
