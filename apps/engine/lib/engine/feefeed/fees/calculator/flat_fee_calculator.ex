defmodule Engine.Feefeed.Fees.Calculator.FlatFee do
  @moduledoc """
  A simple calculator for flat typed fees.
  For a "fixed" type, the amount returned in the fee rule is the amount
  to use for fees, thus there is no need for additional calculation.
  """
  @behaviour Engine.Feefeed.Fees.Calculator.Behaviour

  @impl Engine.Feefeed.Fees.Calculator.Behaviour
  def calculate(currency_rules, _opts), do: {:ok, currency_rules}
end
