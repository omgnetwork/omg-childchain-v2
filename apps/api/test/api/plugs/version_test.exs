defmodule API.Plugs.VersionTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias API.Plugs.Version

  describe "call/2" do
    test "sets the given version to the :api_version assign of the conn" do
      conn =
        :post
        |> conn("/")
        |> Version.call("1.2.3")

      assert conn.assigns[:api_version] == "1.2.3"
    end
  end
end
