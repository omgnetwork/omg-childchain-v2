defmodule SubmitBlockTest do
  use Engine.DB.DataCase, async: false

  alias Engine.Configuration
  alias Engine.Ethereum.Authority.Submitter
  alias Engine.Ethereum.Authority.Submitter.External
  alias Engine.Ethereum.RootChain.Rpc
  alias Engine.Geth
  alias Engine.Plugin
  alias ExPlasma.Encoding

  @moduletag :block_submission
  # placeholder for send raw transaction test
  setup_all do
    # https://github.com/omisego-images/docker-elixir-omg/blob/6beba75b5eb718be90e05e3d5c9f23bff41a4a1b/contracts/docker-compose.yml#L31
    System.put_env("PRIVATE_KEY", "7f30f140fd4724519e5017c0895f158d68bbbe4a81c0c10dbb25a0006e348807")
    {:ok, {geth_pid, _geth_container_id}} = Geth.start(8545)

    on_exit(fn ->
      GenServer.stop(geth_pid)
    end)

    :ok
  end

  test "submit a sealed block to plasma contracts and check that it was accepted" do
        Plugin.verify(true, true, false)
    enterprise = 0
    rpc_url = "http://localhost:8545"
    vault_url = nil
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
        http_request_options: []
      ],
      gas_integration_fallback_order: [nil],
      enterprise: enterprise
    ]

    {:ok, eth_block_number} = Rpc.eth_block_number(url: rpc_url)
    height = Encoding.to_int(eth_block_number)
    {:ok, pid} = Submitter.start_link(submitter_opts)
    event = Bus.Event.new({:root_chain, "ethereum_new_height"}, :ethereum_new_height, height)
    Bus.local_broadcast(event)
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
