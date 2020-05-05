defmodule Engine.Fees.Adapter do
  @moduledoc """
  Behaviour for fee adapters.
  """
  alias Engine.Fees

  @callback get_fee_specs(Keyword.t(), OMG.Fees.full_fee_t(), pos_integer()) ::
              {:ok, Fees.full_fee_t(), pos_integer()}
              | {:error, atom() | [{:error, atom()}, ...]}
end
