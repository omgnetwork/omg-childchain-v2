defmodule Engine.Ethereum.Authority.Submitter.ExternalTest do
  use ExUnit.Case, async: true
  alias Engine.Ethereum.Authority.Submitter.External

  test "external call to get next child block " do
    parent = self()
    pid = spawn(fn -> __MODULE__.EthereumClient.start(8885, parent) end)

    receive do
      :done -> :ok
    after
      500 -> raise("we ded")
    end

    assert External.next_child_block("doesn't matter because fake server", url: "http://127.0.0.1:8885") == 0
    Kernel.send(pid, :stop)
  end

  test "external call to submit block (whatever that is we don't really know)", %{test: test_name} do
    parent = self()
    plasma_framework = "plasma_framework_address"
    enteprise = 0

    defmodule test_name do
      def fake(_, _, _, _, opts), do: Kernel.send(Keyword.fetch!(opts, :parent), :done_calling)
    end

    opts = [module: test_name, function: :fake, parent: parent]
    call = External.submit_block(plasma_framework, enteprise, opts)
    call.(1, 2, 3)

    receive do
      :done_calling ->
        assert true
    after
      500 ->
        assert false
    end
  end

  defmodule EthereumClient do
    # a very simple http client implementation that we can twist into responses that we need
    def start(port, parent) do
      {:ok, sock} = :gen_tcp.listen(port, [:binary, {:active, false}])
      spawn(fn -> loop(sock) end)
      Kernel.send(parent, :done)

      receive do
        :stop ->
          :gen_tcp.close(sock)
      end
    end

    defp loop(sock) do
      case :gen_tcp.accept(sock) do
        {:ok, conn} ->
          handler = spawn(fn -> handle(conn) end)
          :gen_tcp.controlling_process(conn, handler)
          loop(sock)

        _ ->
          :ok
      end
    end

    defp handle(conn) do
      body = %{
        "id" => 83,
        "jsonrpc" => "2.0",
        "result" =>
          "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
      }

      :ok = :gen_tcp.send(conn, ["HTTP/1.0 ", Integer.to_charlist(200), "\r\n", [], "\r\n", Jason.encode!(body)])
      :gen_tcp.close(conn)
    end
  end
end
