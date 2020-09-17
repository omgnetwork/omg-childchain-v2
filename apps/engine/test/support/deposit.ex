defmodule Deposit do
  @moduledoc false

  alias ExPlasma.Builder
  alias ExPlasma.Transaction.Type.PaymentV1

  def new(owner, token, amount) do
    output = PaymentV1.new_output(owner, token, amount)
    Builder.new(ExPlasma.payment_v1(), outputs: [output])
  end
end
