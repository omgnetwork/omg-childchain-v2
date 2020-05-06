defmodule Engine.Feefeed.Fees.Calculator.Behaviour do
  @moduledoc """
  Defines the behaviour that each calculator modules will need
  to conform to.
  """

  alias Engine.DB.FeeRules
  alias Engine.DB.Fees

  @callback calculate(FeeRules.fee_rule_data_currency_t(), keyword()) ::
              {:ok, Fees.fee_data_currency_t()}
end
