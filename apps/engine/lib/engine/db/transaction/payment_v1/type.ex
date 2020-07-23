defmodule Engine.DB.Transaction.PaymentV1.Type do
  @moduledoc false

  @type output_list_t() :: list(ExPlasma.Output.Type.PaymentV1.t())
  @type accepted_fees_t() :: %{required(<<_::160>>) => list(pos_integer())}
  @type optional_accepted_fees_t() :: accepted_fees_t() | :no_fees_required
end
