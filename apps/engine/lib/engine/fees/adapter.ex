defmodule Engine.Fees.Adapter do
  @moduledoc """
  Behaviour for fee adapters.
  """

  @callback get_fee_specs(Keyword.t(), Engine.Fees.Fees.full_fee_t(), pos_integer()) ::
              {:ok, Engine.Fees.Fees.full_fee_t(), pos_integer()}
              | {:error, atom() | [{:error, atom()}, ...]}
end
