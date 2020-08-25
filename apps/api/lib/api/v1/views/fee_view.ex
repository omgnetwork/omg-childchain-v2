defmodule API.V1.View.Fee do
  @moduledoc """
  Contain functions that serialize fees into different format
  """

  alias ExPlasma.Encoding

  def serialize(fees) do
    fees
    |> Enum.map(&parse_for_type/1)
    |> Enum.into(%{})
  end

  defp parse_for_type({tx_type, fees}) do
    {Integer.to_string(tx_type), Enum.map(fees, &parse_for_token/1)}
  end

  defp parse_for_token({currency, fee}) do
    %{
      currency: Encoding.to_hex(currency),
      amount: fee.amount,
      subunit_to_unit: fee.subunit_to_unit,
      pegged_currency: fee.pegged_currency,
      pegged_amount: fee.pegged_amount,
      pegged_subunit_to_unit: fee.pegged_subunit_to_unit,
      updated_at: fee.updated_at
    }
  end
end
