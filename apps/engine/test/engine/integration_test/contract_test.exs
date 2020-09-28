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
          rpc_url: "http://localhost:36652",
          authority_address: "0xc0f780dfc35075979b0def588d999225b7ecc56f",
          plasma_framework: "0xc673e4ffcb8464faff908a6804fe0e635af0ea2f",
          eth_vault: "0xacfcf2770708f4b2d67efde9099fec883590c55f",
          erc20_vault: "0x23764956b3fc5f3d86586b1422ca528559a07161",
          payment_exit_game: "0x32a74e03df3cc8c5abf69f4628af9ef36bc22d1a",
          min_exit_period_seconds: 20,
          contract_semver: "2.0.0+8468675",
          child_block_interval: 1000,
          contract_deployment_height: 78
        ]
      ]

      config = Contract.load([{:ethereumex, [url: "not used because env var"]}], [])
      assert engine_setup == config
    end
  end
end
