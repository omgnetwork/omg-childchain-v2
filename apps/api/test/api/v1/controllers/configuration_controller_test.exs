defmodule API.V1.Controller.ConfigurationTest do
  use ExUnit.Case, async: false

  alias API.V1.Controller.Configuration

  @app :engine

  describe "get/0" do
    setup do
      original = %{
        finality_margin: Application.get_env(@app, :finality_margin),
        network: Application.get_env(@app, :network),
        contract_semver: Application.get_env(@app, :contract_semver)
      }

      Application.put_env(@app, :finality_margin, 123)
      Application.put_env(@app, :network, "some_network")
      Application.put_env(@app, :contract_semver, "some_contract_semver")

      on_exit(fn ->
        Application.put_env(@app, :finality_margin, original.finality_margin)
        Application.put_env(@app, :network, original.network)
        Application.put_env(@app, :contract_semver, original.contract_semver)
      end)
    end

    test "returns configuration successfuly" do
      assert Configuration.get() ==
               {:ok,
                %{
                  deposit_finality_margin: 123,
                  contract_semver: "some_contract_semver",
                  network: "some_network",
                  object: "configuration"
                }}
    end
  end
end
