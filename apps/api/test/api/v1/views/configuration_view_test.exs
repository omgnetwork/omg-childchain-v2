defmodule API.V1.View.ConfigurationTest do
  use ExUnit.Case, async: true

  alias API.V1.View.Configuration

  describe "serialize/1" do
    test "serialize a configuration" do
      configuration = %{
        finality_margin: 123,
        contract_semver: "contract_semver",
        ethereum_network: "ethereum_network"
      }

      assert Configuration.serialize(configuration) == %{
               object: "configuration",
               deposit_finality_margin: configuration.finality_margin,
               contract_semver: configuration.contract_semver,
               network: configuration.ethereum_network
             }
    end
  end
end
