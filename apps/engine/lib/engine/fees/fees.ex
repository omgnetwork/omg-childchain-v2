defmodule Engine.Fees.Fees do
  @moduledoc """
  Transaction's fee validation functions.
  """

  @typedoc "A map of token addresses to a single fee spec"
  @type fee_t() :: %{address_t() => fee_spec_t()}
  @typedoc """
  A map of transaction types to fees
  where fees is itself a map of token to fee spec
  """
  @type full_fee_t() :: %{non_neg_integer() => fee_t()}
  @type optional_fee_t() :: merged_fee_t() | :ignore_fees | :no_fees_required
  @type address_t() :: <<_::160>>
  @typedoc "A map representing a single fee"
  @type fee_spec_t() :: %{
          amount: pos_integer(),
          subunit_to_unit: pos_integer(),
          pegged_amount: pos_integer(),
          pegged_currency: String.t(),
          pegged_subunit_to_unit: pos_integer(),
          updated_at: DateTime.t()
        }

  @typedoc """
  A map of currency to amounts used internally where amounts is a list of supported fee amounts.
  """
  @type typed_merged_fee_t() :: %{non_neg_integer() => merged_fee_t()}
  @type merged_fee_t() :: %{address_t() => list(pos_integer())}
end
