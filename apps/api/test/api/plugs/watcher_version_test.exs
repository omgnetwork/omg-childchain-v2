defmodule API.Plugs.WatcherVersionTest do
  use ExUnit.Case, async: false
  use Plug.Test

  alias API.Plugs.WatcherVersion

  @header "x-watcher-version"

  describe "call/2" do
    test "does not crash when there is no x_watcher_version header" do
      conn = conn(:post, "/")

      assert WatcherVersion.call(conn, metrics_module: __MODULE__) == conn
      refute_receive(_)
    end

    test "gathers stats on  x_watcher_version header if it matches the format" do
      conn = conn_with_header("1.0.13+f938a13")

      assert WatcherVersion.call(conn, metrics_module: __MODULE__) == conn

      assert_receive(:"x_watcher_version-1.0.13+f938a13")
    end

    test "does not gather stats on  x_watcher_version header if it does not match the format" do
      _ = WatcherVersion.call(conn_with_header("1.0.13f938a13"), metrics_module: __MODULE__)
      refute_receive(_)

      _ = WatcherVersion.call(conn_with_header("1.0.13+f93.a13"), metrics_module: __MODULE__)
      refute_receive(_)

      _ = WatcherVersion.call(conn_with_header("fa+f938a13"), metrics_module: __MODULE__)
      refute_receive(_)

      _ = WatcherVersion.call(conn_with_header("+_())(_+"), metrics_module: __MODULE__)
      refute_receive(_)
    end
  end

  def increment(event), do: send(self(), String.to_existing_atom(event))

  defp conn_with_header(header_value) do
    :post
    |> conn("/")
    |> put_req_header(@header, header_value)
  end
end
