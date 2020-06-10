defmodule Engine.Fees.Fetcher.Client.Parser.SingleSpecParser do
  @moduledoc """
  Parsing module for a single fee spec
  """
  require Logger

  @typedoc """
  The fee spec for a specific type/token is missing keys:

  - :invalid_fee_spec - the fee spec is invalid
  - :invalid_fee - the fee amount is invalid (must be >= 0)
  - :invalid_subunit_to_unit - the subunit to unit is invalid (must be > 0)
  - :invalid_pegged_amount - the pegged amount is invalid (must be > 0)
  - :invalid_pegged_currency - the pegged currency is invalid (must be > 0)
  - :invalid_pegged_subunit_to_unit - the pegged subunit to unit is invalid (must be > 0)
  - :invalid_timestamp - the updated at date is invalid (wrong date format)
  - :bad_address_encoding - the token address is invalid (must be a valid Ethereum address)
  - :invalid_pegged_fields - pegged fields must either be all nil or all not nil
  - :unsupported_fee_type - at the moment only "fixed" fee type is supported
  """
  @type parsing_error() ::
          :invalid_fee_spec
          | :invalid_fee
          | :invalid_subunit_to_unit
          | :invalid_pegged_amount
          | :invalid_pegged_currency
          | :invalid_pegged_subunit_to_unit
          | :invalid_timestamp
          | :bad_address_encoding
          | :invalid_pegged_fields
          | :unsupported_fee_type

  @doc """
  Parses and validates a single fee spec
  """
  @spec parse({binary(), map()}) :: {:ok, map()} | {:error, parsing_error()}
  def parse(
        {token,
         %{
           "amount" => fee,
           "subunit_to_unit" => subunit_to_unit,
           "pegged_amount" => pegged_amount,
           "pegged_currency" => pegged_currency,
           "pegged_subunit_to_unit" => pegged_subunit_to_unit,
           "updated_at" => updated_at,
           "type" => fee_type
         }}
      ) do
    # defensive code against user input
    with {:ok, fee} <- validate_positive_amount(fee, :invalid_fee),
         {:ok, addr} <- decode_address(token),
         {:ok, subunit_to_unit} <- validate_positive_amount(subunit_to_unit, :invalid_subunit_to_unit),
         {:ok, pegged_amount} <- validate_optional_positive_amount(pegged_amount, :invalid_pegged_amount),
         {:ok, pegged_currency} <- validate_pegged_currency(pegged_currency),
         {:ok, pegged_subunit_to_unit} <-
           validate_optional_positive_integer_amount(pegged_subunit_to_unit, :invalid_pegged_subunit_to_unit),
         :ok <- validate_pegged_fields(pegged_currency, pegged_amount, pegged_subunit_to_unit),
         {:ok, updated_at} <- validate_updated_at(updated_at),
         {:ok, fee_type} <- validate_fee_type(fee_type) do
      {:ok,
       %{
         token: addr,
         amount: fee,
         subunit_to_unit: subunit_to_unit,
         pegged_amount: pegged_amount,
         pegged_currency: pegged_currency,
         pegged_subunit_to_unit: pegged_subunit_to_unit,
         type: fee_type,
         updated_at: updated_at
       }}
    end
  end

  def parse(_), do: {:error, :invalid_fee_spec}

  defp validate_positive_amount(amount, _error) when is_integer(amount) and amount > 0, do: {:ok, amount}
  defp validate_positive_amount(_amount, error), do: {:error, error}

  defp validate_optional_positive_integer_amount(nil, _error), do: {:ok, nil}

  defp validate_optional_positive_integer_amount(amount, _error) when is_integer(amount) and amount > 0 do
    {:ok, amount}
  end

  defp validate_optional_positive_integer_amount(_amount, error), do: {:error, error}

  defp validate_optional_positive_amount(nil, _error), do: {:ok, nil}
  defp validate_optional_positive_amount(amount, _error) when amount > 0, do: {:ok, amount}
  defp validate_optional_positive_amount(_amount, error), do: {:error, error}

  defp validate_pegged_currency(nil), do: {:ok, nil}
  defp validate_pegged_currency(pegged_currency) when is_binary(pegged_currency), do: {:ok, pegged_currency}
  defp validate_pegged_currency(_pegged_currency), do: {:error, :invalid_pegged_currency}

  defp validate_pegged_fields(nil, nil, nil), do: :ok

  defp validate_pegged_fields(currency, amount, subunit_to_unit)
       when not is_nil(currency) and not is_nil(amount) and not is_nil(subunit_to_unit) do
    :ok
  end

  defp validate_pegged_fields(_, _, _), do: {:error, :invalid_pegged_fields}

  defp validate_updated_at(updated_at) do
    case DateTime.from_iso8601(updated_at) do
      {:ok, %DateTime{} = date_time, _} -> {:ok, date_time}
      _ -> {:error, :invalid_timestamp}
    end
  end

  defp decode_address("0x" <> data), do: decode_address(data)

  defp decode_address(data) do
    case Base.decode16(data, case: :mixed) do
      {:ok, address} when byte_size(address) == 20 ->
        {:ok, address}

      _ ->
        {:error, :bad_address_encoding}
    end
  end

  defp validate_fee_type("fixed"), do: {:ok, :fixed}
  defp validate_fee_type("pegged"), do: {:ok, :pegged}
  defp validate_fee_type(_), do: {:error, :unsupported_fee_type}
end