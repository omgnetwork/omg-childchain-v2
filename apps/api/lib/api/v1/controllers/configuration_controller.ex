defmodule API.V1.Controller.ConfigurationController do
  @moduledoc """
  Contains configuration related API functions.
  """

  use Spandex.Decorators

  alias API.V1.View.ConfigurationView
  alias Engine.Configuration

  @doc """
  Returns the current configuration.
  """
  @spec get() :: {:ok, ConfigurationView.serialized()}
  @decorate trace(service: :ecto, type: :backend)
  def get() do
    configuration = %{
      finality_margin: Configuration.finality_margin(),
      contract_semver: Configuration.contract_semver(),
      ethereum_network: Configuration.ethereum_network()
    }

    {:ok, ConfigurationView.serialize(configuration)}
  end
end
