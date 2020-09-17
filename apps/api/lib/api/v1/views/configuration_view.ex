defmodule API.V1.View.ConfigurationView do
  @moduledoc """
  Contain functions that serialize the configuration
  """

  @type serialized() :: %{
          required(:deposit_finality_margin) => non_neg_integer(),
          required(:contract_semver) => String.t(),
          required(:network) => String.t()
        }

  @spec serialize(map()) :: serialized()
  def serialize(configuration) do
    %{
      deposit_finality_margin: configuration.finality_margin,
      contract_semver: configuration.contract_semver,
      network: configuration.ethereum_network
    }
  end
end
