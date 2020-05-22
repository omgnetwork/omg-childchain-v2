defmodule Engine.DB.Transaction.PaymentV1.DepositValidator do
  @moduledoc """
  Handles statefull validation for transaction type "PaymentV1" (1) and kind "deposit".

  See validate/3 for more details.
  """

  @behaviour Engine.DB.Transaction.Validator

  @doc """
  Validates that a deposit transaction is valid.
  There is no reason it should be invalid as it's generated internally
  by listening contract events.

  Returns `:ok` if the deposit is valid, or raises an error otherwise.

  ## Example:

  iex> Engine.DB.Transaction.PaymentV1.DepositValidator.validate([], [
  ...> %{output_guard: <<2::160>>, token: <<2::160>>, amount: 2}],
  ...> %{})
  :ok
  """
  @spec validate(
          list(),
          list(ExPlasma.Output.Type.PaymentV1.t()),
          map()
        ) :: :ok | no_return()
  @impl Engine.DB.Transaction.Validator
  def validate([], [_output], _), do: :ok
  def validate(_, [_output], _), do: raise(ArgumentError, "deposits should not have inputs")
  def validate([], _, _), do: raise(ArgumentError, "deposit should have 1 output only")
end
