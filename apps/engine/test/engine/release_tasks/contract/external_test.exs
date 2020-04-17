defmodule Engine.ReleaseTasks.Contract.ExternalTest do
  use ExUnit.Case, async: true

  alias __MODULE__.EthereumClient
  alias DBConnection.Backoff
  alias Engine.ReleaseTasks.Contract.External

  setup_all do
    starting_port = 9000
    Agent.start_link(fn -> starting_port end, name: __MODULE__)
    :ok
  end

  setup context do
    %{test: test_name} = context
    port = Agent.get_and_update(__MODULE__, fn state -> {state, state + 1} end)
    _ = Kernel.spawn_link(EthereumClient, :start, [port, test_name])
    %{port: port}
  end

  describe "min_exit_period/1" do
    test "that the returned data is a number", %{test: test_name, port: port} do
      execution = fn _index, conn ->
        response = "0x0000000000000000000000000000000000000000000000000000000000000014"

        body = %{
          "id" => 1,
          "jsonrpc" => "2.0",
          "result" => response
        }

        body = Jason.encode!(body)

        :ok = :gen_tcp.send(conn, ["HTTP/1.0 ", Integer.to_charlist(200), "\r\n", [], "\r\n", body])

        :gen_tcp.close(conn)
      end

      Agent.start_link(fn -> {0, execution} end, name: test_name)
      min_exit_period = External.min_exit_period("contract address", [{:url, "http://localhost:#{port}"}])
      assert min_exit_period == 20
    end
  end

  describe "exit_game_contract_address/2" do
    test "that the returned data is an address", %{test: test_name, port: port} do
      execution = fn _index, conn ->
        response = "0x00000000000000000000000089afce326e7da55647d22e24336c6a2816c99f6b"

        body = %{
          "id" => 1,
          "jsonrpc" => "2.0",
          "result" => response
        }

        body = Jason.encode!(body)

        :ok = :gen_tcp.send(conn, ["HTTP/1.0 ", Integer.to_charlist(200), "\r\n", [], "\r\n", body])

        :gen_tcp.close(conn)
      end

      Agent.start_link(fn -> {0, execution} end, name: test_name)

      exit_game_contract_address =
        External.exit_game_contract_address("contract address", 1, [{:url, "http://localhost:#{port}"}])

      assert exit_game_contract_address == "0x89afce326e7da55647d22e24336c6a2816c99f6b"
    end
  end

  describe "vault/2" do
    test "that the returned data is an address", %{test: test_name, port: port} do
      execution = fn _index, conn ->
        response = "0x00000000000000000000000089afce326e7da55647d22e24336c6a2816c99f6b"

        body = %{
          "id" => 1,
          "jsonrpc" => "2.0",
          "result" => response
        }

        body = Jason.encode!(body)

        :ok = :gen_tcp.send(conn, ["HTTP/1.0 ", Integer.to_charlist(200), "\r\n", [], "\r\n", body])

        :gen_tcp.close(conn)
      end

      Agent.start_link(fn -> {0, execution} end, name: test_name)
      vault_address = External.vault("contract address", 1, [{:url, "http://localhost:#{port}"}])
      assert vault_address == "0x89afce326e7da55647d22e24336c6a2816c99f6b"
    end
  end

  describe "contract_semver/1" do
    test "that the returned data is a semver", %{test: test_name, port: port} do
      execution = fn _index, conn ->
        response =
          "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000d312e302e342b6136396337363300000000000000000000000000000000000000"

        body = %{
          "id" => 1,
          "jsonrpc" => "2.0",
          "result" => response
        }

        body = Jason.encode!(body)

        :ok = :gen_tcp.send(conn, ["HTTP/1.0 ", Integer.to_charlist(200), "\r\n", [], "\r\n", body])

        :gen_tcp.close(conn)
      end

      Agent.start_link(fn -> {0, execution} end, name: test_name)

      contract_semver = External.contract_semver("contract address", [{:url, "http://localhost:#{port}"}])
      assert contract_semver == "1.0.4+a69c763"
      version = Version.parse!(contract_semver)
      assert version.major == 1
      assert version.minor == 0
      assert version.patch == 4
      assert version.build == "a69c763"
    end
  end

  describe "childBlockInterval/1" do
    test "that the returned data is an integer", %{test: test_name, port: port} do
      execution = fn _index, conn ->
        body = %{
          "id" => 1,
          "jsonrpc" => "2.0",
          "result" => "0x00000000000000000000000000000000000000000000000000000000000003e8"
        }

        body = Jason.encode!(body)

        :ok = :gen_tcp.send(conn, ["HTTP/1.0 ", Integer.to_charlist(200), "\r\n", [], "\r\n", body])

        :gen_tcp.close(conn)
      end

      Agent.start_link(fn -> {0, execution} end, name: test_name)

      child_block_interval = External.child_block_interval("contract address", [{:url, "http://localhost:#{port}"}])
      assert child_block_interval == 1000
    end
  end

  describe "call/4" do
    test "if the client closes the connection we retry - :closed", %{test: test_name, port: port} do
      execution = fn index, conn ->
        case index do
          0 ->
            :gen_tcp.close(conn)

          1 ->
            body = %{
              "id" => 1,
              "jsonrpc" => "2.0",
              "result" => "0x0000000000000000000000000000000000000000000000000000000000000014"
            }

            body = Jason.encode!(body)

            :ok = :gen_tcp.send(conn, ["HTTP/1.0 ", Integer.to_charlist(200), "\r\n", [], "\r\n", body])

            :gen_tcp.close(conn)
        end
      end

      Agent.start_link(fn -> {0, execution} end, name: test_name)
      backoff = Backoff.new(backoff_min: 1, backoff_max: 10)
      Process.put(:backoff, backoff)
      min_exit_period = External.min_exit_period("contract address", [{:url, "http://localhost:#{port}"}])
      assert min_exit_period == 20
    end
  end

  defmodule EthereumClient do
    # a very simple Geth implementation that we can twist into responses that we need
    def start(port, agent_name) do
      {:ok, sock} = :gen_tcp.listen(port, [{:active, false}])
      spawn(fn -> loop(sock, agent_name) end)

      receive do
        :stop ->
          :gen_tcp.close(sock)
      end
    end

    defp loop(sock, agent_name) do
      case :gen_tcp.accept(sock) do
        {:ok, conn} ->
          handler = spawn(fn -> handle(conn, agent_name) end)
          :gen_tcp.controlling_process(conn, handler)
          loop(sock, agent_name)

        _ ->
          :ok
      end
    end

    defp handle(conn, agent_name) do
      {index, execution} = Agent.get(agent_name, fn state -> state end)
      Agent.update(agent_name, fn {index, execution} -> {index + 1, execution} end)
      execution.(index, conn)
    end
  end
end
