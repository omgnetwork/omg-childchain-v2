defmodule SubmitBlockVaultTest do
  use Engine.DB.DataCase, async: false

  alias Engine.Configuration
  alias Engine.Ethereum.Authority.Submitter
  alias Engine.Ethereum.Authority.Submitter.External
  alias Engine.Ethereum.RootChain.Rpc
  alias Engine.Geth
  alias Engine.Vault
  alias ExPlasma.Encoding

  @moduletag :block_submission_vault

  setup_all do
    local_umbrella_path = Path.join([File.cwd!(), "../../", "localchain_contract_addresses.env"])

    contract_addreses_path =
      case File.exists?(local_umbrella_path) do
        true ->
          local_umbrella_path

        _ ->
          # CI/CD
          Path.join([File.cwd!(), "localchain_contract_addresses.env"])
      end

    vault_token =
      contract_addreses_path
      |> File.read!()
      |> String.split("\n", trim: true)
      |> List.flatten()
      |> Enum.reduce(%{}, fn line, acc ->
        [key, value] = String.split(line, "=")
        Map.put(acc, key, value)
      end)
      |> Map.get("VAULT_TOKEN")

    :ok = System.put_env("WALLET_NAME", "plasma-deployer")
    :ok = System.put_env("VAULT_TOKEN", vault_token)
    :ok = System.put_env("AUTHORITY_ADDRESS", Configuration.authority_address())

    {:ok, {geth_pid, geth_container_id}} = Geth.start(8545)
    {:ok, {vault_pid, _vault_container_id}} = Vault.start(logs: true, geth_container_id: geth_container_id)

    on_exit(fn ->
      spawn(fn -> GenServer.stop(vault_pid) end)
      GenServer.stop(geth_pid)
    end)

    :ok
  end

  test "submit a sealed block to the vault and check that it was accepted in plasma contracts" do
    enterprise = 1
    rpc_url = "http://localhost:8545"
    vault_url = "https://127.0.0.1:8200"
    next_block = External.next_child_block(Configuration.plasma_framework(), url: rpc_url)
    insert(:block, nonce: Kernel.round(next_block / 1000) - 1, blknum: next_block)

    submitter_opts = [
      plasma_framework: Configuration.plasma_framework(),
      child_block_interval: Configuration.child_block_interval(),
      opts: [
        module: SubmitBlock,
        function: :submit_block,
        url: rpc_url,
        vault_url: vault_url,
        http_request_options: [hackney: [:insecure]]
      ],
      gas_integration_fallback_order: [
        Gas.Integration.Etherscan,
        Gas.Integration.GasPriceOracle,
        Gas.Integration.Pulse,
        Gas.Integration.Web3Api
      ],
      enterprise: enterprise
    ]

    {:ok, eth_block_number} = Rpc.eth_block_number(url: rpc_url)
    height = Encoding.to_int(eth_block_number)
    {:ok, pid} = Submitter.start_link(submitter_opts)
    send(pid, {:internal_event_bus, :ethereum_new_height, height})
    assert Process.alive?(pid)
    # lets just wait a little bit for the block to be mined
    _ = Process.sleep(2000)

    wait(
      fn -> External.next_child_block(Configuration.plasma_framework(), url: rpc_url) end,
      next_block + 1000
    )
  end

  defp wait(fun, next_block) do
    wait(fun, next_block, 20)
  end

  defp wait(_fun, _next_block, 0) do
    assert false
  end

  defp wait(fun, next_block, counter) do
    case fun.() do
      ^next_block ->
        assert true

      _ ->
        Process.sleep(1000)
        wait(fun, next_block, counter - 1)
    end
  end
end
