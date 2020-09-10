defmodule API.V1.Controller.Configuration do
  @moduledoc """
  Contains configuration related API functions.
  """

  use Spandex.Decorators

  alias API.V1.View
  alias Engine.Configuration

  @doc """
  Returns the current configuration.
  """
  @spec get() :: {:ok, View.Configuration.serialized()}
  @decorate trace(service: :ecto, type: :backend)
  def get() do
    configuration = %{
      finality_margin: Configuration.finality_margin(),
      contract_semver: Configuration.contract_semver(),
      ethereum_network: Configuration.ethereum_network()
    }

    {:ok, View.Configuration.serialize(configuration)}
  end
end
