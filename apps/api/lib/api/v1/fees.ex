defmodule API.V1.Fees do
  @moduledoc """
  Fetches fees and returns data for the API response.
  """

  alias Engine.Fees.{FeeFilter, FeeServer}

  @type fees_response() :: %{
          required(String.t()) => fee_type()
        }

  @type fee_type() :: %{
          required(:amount) => pos_integer(),
          required(:currency) => String.t(),
          required(:subunit_to_unit) => pos_integer(),
          required(:pegged_amount) => pos_integer(),
          required(:pegged_currency) => String.t(),
          required(:pegged_subunit_to_unit) => pos_integer(),
          required(:updated_at) => String.t()
        }

  @doc """
  Fetches fees.
  """
  @spec all(map()) :: fees_response()
  def all(params) do
    # with {:ok, currencies} <- expect(params, "currencies", list: &to_currency/1, optional: true),
    #      {:ok, tx_types} <- expect(params, "tx_types", list: &to_tx_type/1, optional: true),
    #      {:ok, filtered_fees} <- get_filtered_fees(tx_types, currencies) do
    #   filtered_fees
    # end

    get_filtered_fees(params, params)
  end

  @spec get_filtered_fees(list(pos_integer()), list(String.t()) | nil) ::
          {:ok, Fees.full_fee_t()} | {:error, :currency_fee_not_supported}
  defp get_filtered_fees(tx_types, currencies) do
    case FeeServer.current_fees() do
      {:ok, fees} ->
        FeeFilter.filter(fees, tx_types, currencies)

      error ->
        error
    end
  end
end
