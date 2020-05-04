defmodule Engine.ReleaseTasks.ContractTest do
  use ExUnit.Case, async: true

  alias __MODULE__.EthereumClient
  alias Engine.ReleaseTasks.Contract

  describe "on_load/2" do
    test "plasma_framework, tx_hash and authority_address can be set", %{test: test_name} do
      port = :crypto.rand_uniform(9500, 10_000)
      Agent.start_link(fn -> port end, name: :system_mock)
      pid = Kernel.spawn(EthereumClient, :start, [port, test_name])

      defmodule :system_mock do
        def get_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK") do
          "0xc673e4ffcb8464faff908a6804fe0e635af0ea2f"
        end

        def get_env("AUTHORITY_ADDRESS") do
          "0xc673e4ffcb8464faff908a6804fe0e635af0ea2f"
        end

        def get_env("TX_HASH_CONTRACT") do
          "0xb836b6c4eb016e430b8e7495db92357896c1da263c6a3de73320b669eb5912d3"
        end

        def get_env("ETHEREUM_RPC_URL") do
          port = Agent.get(__MODULE__, fn state -> state end)
          "http://localhost:#{port}/"
        end
      end

      execution = response_handler_function()

      engine_setup = [
        ethereumex: [url: "default_url"],
        engine: [
          rpc_url: "http://localhost:#{port}/",
          authority_address: "0xc673e4ffcb8464faff908a6804fe0e635af0ea2f",
          plasma_framework: "0xc673e4ffcb8464faff908a6804fe0e635af0ea2f",
          eth_vault: "0x4e3aeff70f022a6d4cc5947423887e7152826cf7",
          erc20_vault: "0x4e3aeff70f022a6d4cc5947423887e7152826cf7",
          payment_exit_game: "0x4e3aeff70f022a6d4cc5947423887e7152826cf7",
          min_exit_period_seconds: 20,
          contract_semver: "1.0.4+a69c763",
          child_block_interval: 20,
          contract_deployment_height: 1
        ]
      ]

      Agent.start_link(fn -> execution end, name: test_name)
      assert Contract.load([ethereumex: [url: "default_url"]], system_adapter: :system_mock) == engine_setup
      Kernel.send(pid, :stop)
    end
  end

  # this anonymous function will
  # get invoked for every request
  # on a specific server startup
  defp response_handler_function() do
    fn method, params, conn ->
      response =
        case method do
          "eth_call" ->
            data = params |> hd() |> Map.get("data")
            <<function::binary-size(10), _::binary>> = data

            get_response(function)

          "eth_getTransactionReceipt" ->
            %{"contractAddress" => "0xc673e4ffcb8464faff908a6804fe0e635af0ea2f", "blockNumber" => "0x1"}
        end

      body = %{
        "id" => 1,
        "jsonrpc" => "2.0",
        "result" => response
      }

      body = Jason.encode!(body)
      :ok = :gen_tcp.send(conn, ["HTTP/1.0 ", Integer.to_charlist(200), "\r\n", [], "\r\n", body])
      :gen_tcp.close(conn)
    end
  end

  # getVersion()
  defp get_response("0x0d8e6e2c") do
    "0x0000000000000000000000000000000000000000000000" <>
      "000000000000000020000000000000000000000000000000" <>
      "000000000000000000000000000000000d312e302e342b61" <>
      "36396337363300000000000000000000000000000000000000"
  end

  # vaults
  defp get_response("0x8c64ea4a") do
    "0x0000000000000000000000004e3aeff70f022a6d4cc5947423887e7152826cf7"
  end

  # payment exit game
  defp get_response("0xaf079764") do
    "0x0000000000000000000000004e3aeff70f022a6d4cc5947423887e7152826cf7"
  end

  # payment exit game
  defp get_response(_) do
    "0x0000000000000000000000000000000000000000000000000000000000000014"
  end

  defmodule EthereumClient do
    # a very simple http client implementation that we can twist into responses that we need
    def start(port, test_name) do
      {:ok, sock} = :gen_tcp.listen(port, [:binary, {:active, false}])
      spawn(fn -> loop(sock, test_name) end)

      receive do
        :stop ->
          :gen_tcp.close(sock)
      end
    end

    defp loop(sock, test_name) do
      case :gen_tcp.accept(sock) do
        {:ok, conn} ->
          handler = spawn(fn -> handle(conn, test_name) end)
          :gen_tcp.controlling_process(conn, handler)
          loop(sock, test_name)

        _ ->
          :ok
      end
    end

    defp handle(conn, test_name) do
      {:ok, body} = :gen_tcp.recv(conn, 0)
      [_, request] = String.split(body, "\r\n\r\n")
      method = request |> Jason.decode!() |> Map.get("method")
      params = request |> Jason.decode!() |> Map.get("params")
      execution = Agent.get(test_name, fn state -> state end)
      execution.(method, params, conn)
    end
  end
end
