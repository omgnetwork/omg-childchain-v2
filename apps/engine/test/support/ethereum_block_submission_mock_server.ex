defmodule EthereumBlockSubmissionMockServer do
  alias ExPlasma.Encoding

  use GenServer

  def get_height(server) do
    GenServer.call(server, :get_height)
  end

  def start_link(init_arg) do
    name =
      init_arg
      |> Keyword.fetch!(:port)
      |> Integer.to_string()
      |> String.to_atom()

    GenServer.start_link(__MODULE__, init_arg, name: name)
  end

  @type t :: %__MODULE__{
          sock: :gen_tcp.socket(),
          port: non_neg_integer(),
          interval: non_neg_integer(),
          height: non_neg_integer()
        }
  defstruct [:sock, :port, :interval, height: 1]

  def init(init_arg) do
    port = Keyword.fetch!(init_arg, :port)
    interval = Keyword.get(init_arg, :interval, 15_000)
    {:ok, sock} = :gen_tcp.listen(port, [:binary, {:active, false}])
    _ = :timer.send_after(interval, self(), :inc)
    {:ok, %__MODULE__{sock: sock, port: port, interval: interval}, {:continue, :start}}
  end

  def handle_info(:inc, state) do
    _ = :timer.send_after(state.interval, self(), :inc)
    {:noreply, %{state | height: state.height + 1}}
  end

  def handle_continue(:start, state) do
    parent = self()
    _pid = spawn(fn -> loop(state.sock, parent) end)
    {:noreply, state}
  end

  def handle_call(:get_height, _, state) do
    {:reply, Encoding.to_hex(state.height), state}
  end

  def terminate(_reason, state) do
    :gen_tcp.close(state.sock)
  end

  defp loop(sock, parent) do
    case :gen_tcp.accept(sock) do
      {:ok, conn} ->
        handler = spawn(fn -> handle(conn, parent) end)
        :gen_tcp.controlling_process(conn, handler)
        loop(sock, parent)

      _ ->
        :ok
    end
  end

  defp handle(conn, parent) do
    {:ok, body} = :gen_tcp.recv(conn, 0)
    [_, request] = String.split(body, "\r\n\r\n")
    method = request |> Jason.decode!() |> Map.get("method")
    params = request |> Jason.decode!() |> Map.get("params")

    exchanger_body = method(method, params, parent)

    body = Jason.encode!(exchanger_body)

    :ok = :gen_tcp.send(conn, ["HTTP/1.0 ", Integer.to_charlist(200), "\r\n", [], "\r\n", body])

    :gen_tcp.close(conn)
  end

  defp method("eth_blockNumber", _params, parent) do
    %{
      "id" => 83,
      "jsonrpc" => "2.0",
      "result" => __MODULE__.get_height(parent)
    }
  end

  # this isn't a GETH JSON RPC mock, because VAULT
  defp method("send_transaction", %{"hash" => hash, "nonce" => nonce, "gas" => gas}, parent) do
    %{"result" => "OK"}
  end

  # "nextChildBlock()"
  defp method("eth_call", [%{"data" => "0x4ca8714f", "to" => _}, []], parent) do
    "0x" <> other = Encoding.to_hex(1000)

    %{
      "id" => 83,
      "jsonrpc" => "2.0",
      "result" => "0x0000000000000000000000000000000000000000000000000000000000000" <> other
    }
  end
end
