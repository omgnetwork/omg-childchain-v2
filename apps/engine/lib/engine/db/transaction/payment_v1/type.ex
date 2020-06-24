defmodule Engine.DB.Transaction.PaymentV1.Type do
  @moduledoc false

  @type output_list_t() :: list(ExPlasma.Output.Type.PaymentV1.t())
  @type accepted_fees_t() :: %{required(<<_::160>>) => list(pos_integer())}
  @type optional_accepted_fees_t() :: accepted_fees_t() | :no_fees_required

  @type validation_result_t() ::
          :ok
          | {:error, {:inputs, :amounts_do_not_add_up}}
          | {:error, {:inputs, :fees_not_covered}}
          | {:error, {:inputs, :fee_token_not_accepted}}
          | {:error, {:inputs, :overpaying_fees}}
end
