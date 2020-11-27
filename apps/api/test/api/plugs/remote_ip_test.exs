defmodule API.Plugs.RemoteIPTest do
  use ExUnit.Case, async: true

  alias API.Plugs.RemoteIP

  describe "call/2" do
    test "sets remote_ip field" do
      conn = %Plug.Conn{
        req_headers: [
          {"cf-connecting-ip", "99.99.99.99"}
        ]
      }

      conn_with_remote_ip = RemoteIP.call(conn, %{})

      assert conn_with_remote_ip.remote_ip == {99, 99, 99, 99}
    end

    test "does not set remote_ip if cf-connecting-ip header is not set" do
      conn = %Plug.Conn{}

      conn_with_remote_ip = RemoteIP.call(conn, %{})

      assert is_nil(conn_with_remote_ip.remote_ip)
    end

    test "does not set remote_ip if cf-connecting-ip header is invalid" do
      conn = %Plug.Conn{
        req_headers: [
          {"cf-connecting-ip", "myip"}
        ]
      }

      conn_with_remote_ip = RemoteIP.call(conn, %{})

      assert is_nil(conn_with_remote_ip.remote_ip)
    end

    test "sets the left-most ip address" do
      conn = %Plug.Conn{
        req_headers: [
          {"cf-connecting-ip", "77.77.77.77, 99.99.99.99"}
        ]
      }

      conn_with_remote_ip = RemoteIP.call(conn, %{})

      assert conn_with_remote_ip.remote_ip == {77, 77, 77, 77}
    end
  end
end
