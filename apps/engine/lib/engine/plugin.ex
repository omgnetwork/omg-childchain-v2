defmodule Engine.Plugin do
  @moduledoc """
    Plugins (Submit Block and Gas) related code
  """

  require Logger

  @spec verify(boolean(), boolean(), boolean()) :: :ok | no_return()
  def verify(true = _prod, true = _submit_block, false = _gas) do
    create_gas_integration()
    message = "You're in PROD mode. Default Gas module created. SubmitBlock loaded."
    _ = Logger.info(message)
    :ok
  end

  def verify(true, true, true) do
    message = "You're in PROD ENTERPRISE mode. Integrations are loaded."
    _ = Logger.info(message)
    :ok
  end

  def verify(true, _, _) do
    message = "You're in PROD mode. You don't have all integrations loaded. Halting the VM."
    _ = Logger.error(message)
    message |> String.to_charlist() |> :erlang.halt()
  end

  def verify(_, _, _) do
    message = "You're in DEV or TEST mode. You don't have any integrations loaded. Submitting blocks disabled."
    _ = Logger.error(message)
    :ok
  end

  defp create_gas_integration() do
    ast =
      quote do
        defmodule unquote(Gas) do
          defstruct low: 33.0, fast: 80.0, fastest: 85.0, standard: 50.0, name: "Geth"
          def unquote(:gas)(_), do: "Elixir.Gas" |> String.to_atom() |> Kernel.struct!()
          def unquote(:integrations)(), do: []
        end
      end

    {{:module, Gas, _, _}, []} = Code.eval_quoted(ast)
    true = Code.ensure_loaded?(Gas)
  end
end
