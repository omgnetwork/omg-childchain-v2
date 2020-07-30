defmodule API.V1.Fees do
  @moduledoc """
  Fetches fees and returns data for the API response.
  """

  alias Engine.Fees.{FeeFilter, Fees, FeeServer}

  import API.Validator

  @type fees_response() :: %{non_neg_integer() => %{<<_::160>> => fee_type()}}

  @type fee_type() :: %{
          required(:amount) => pos_integer(),
          required(:subunit_to_unit) => pos_integer(),
          required(:pegged_amount) => pos_integer(),
          required(:pegged_currency) => binary(),
          required(:pegged_subunit_to_unit) => pos_integer(),
          required(:updated_at) => DateTime.t()
        }

  @doc """
  Fetches fees.
  """
  @spec all(map()) :: fees_response() | API.Validator.validation_error_t()
  def all(params) do
    with {:ok, currencies} <- expect(params, "currencies", list: &to_currency/1, optional: true),
         {:ok, tx_types} <- expect(params, "tx_types", list: &to_tx_type/1, optional: true),
         {:ok, filtered_fees} <- get_filtered_fees(tx_types, currencies) do
      filtered_fees
    end
  end

  @spec get_filtered_fees(list(pos_integer()), list(String.t()) | nil) ::
          {:ok, Fees.full_fee_t()} | {:error, :currency_fee_not_supported}
  defp get_filtered_fees(tx_types, currencies) do
    {:ok, fees} = FeeServer.current_fees()

    FeeFilter.filter(fees, tx_types, currencies)
  end

  defp to_currency(currency_str) do
    expect(%{"currency" => currency_str}, "currency", :address)
  end

  defp to_tx_type(tx_type_str) do
    expect(%{"tx_type" => tx_type_str}, "tx_type", :non_neg_integer)
  end
end
