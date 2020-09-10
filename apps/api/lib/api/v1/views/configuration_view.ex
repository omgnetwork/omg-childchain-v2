defmodule API.V1.View.Configuration do
  @moduledoc """
  Contain functions that serialize the configuration
  """

  @type serialized() :: %{
          required(:deposit_finality_margin) => non_neg_integer(),
          required(:contract_semver) => String.t(),
          required(:network) => String.t(),
          required(:object) => String.t()
        }

  @spec serialize(map()) :: serialized()
  def serialize(configuration) do
    %{
      object: "configuration",
      deposit_finality_margin: configuration.finality_margin,
      contract_semver: configuration.contract_semver,
      network: configuration.ethereum_network
    }
  end
end
