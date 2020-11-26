defmodule API.Plugs.WatcherVersionTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias API.Plugs.WatcherVersion

  @header "x_watcher_version"

  describe "call/2" do
    test "does not crash when there is no x_watcher_version header" do
      conn = conn(:post, "/")

      assert WatcherVersion.call(conn, %{}) == conn
    end

    test "does not crash when there is x_watcher_version header" do
      conn =
        :post
        |> conn("/")
        |> put_req_header(@header, "1.0.13+f938a13")

      assert WatcherVersion.call(conn, %{}) == conn
    end
  end
end
