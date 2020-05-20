defmodule API.V1.Router do
  @moduledoc """
  The V1 JSON-RPC API. This should have parity with elixir-omg's API.
  """

  use Plug.Router

  plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)

  post "/block.get" do
  end

  post "/transaction.submit" do
  end
end
