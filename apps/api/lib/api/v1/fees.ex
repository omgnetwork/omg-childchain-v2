defmodule API.V1.Fees do
  @moduledoc """
  Fetches fees and returns data for the API response.
  """
  import API.Validator

  alias API.Response
  alias Engine.Fees.{FeeFilter, Fees, FeeServer}

  @type fees_response() :: %{non_neg_integer() => fee_type()}

  @type fee_type() :: %{
          required(:amount) => pos_integer(),
          required(:currency) => String.t(),
          required(:subunit_to_unit) => pos_integer(),
          required(:pegged_amount) => pos_integer(),
          required(:pegged_currency) => binary(),
          required(:pegged_subunit_to_unit) => pos_integer(),
          required(:updated_at) => DateTime.t()
        }

  @errors %{
    tx_type_not_supported: %{
      code: "fee:tx_type_not_supported",
      description: "One or more of the given transaction types are not supported."
    },
    currency_fee_not_supported: %{
      code: "fee:currency_fee_not_supported",
      description: "One or more of the given currencies are not supported as a fee-token."
    },
    operation_not_found: %{
      code: "operation:not_found",
      description: "Operation cannot be found. Check request URL."
    },
    operation_bad_request: %{
      code: "operation:bad_request",
      description: "Parameters required by this operation are missing or incorrect."
    }
  }

  @doc """
  Fetches fees.
  """
  @spec all(Plug.Conn.t()) :: fees_response() | API.Validator.validation_error_t()
  def all(conn) do
    with {:ok, currencies} <- expect(conn.params, "currencies", list: &to_currency/1, optional: true),
         {:ok, tx_types} <- expect(conn.params, "tx_types", list: &to_tx_type/1, optional: true),
         {:ok, filtered_fees} <- get_filtered_fees(tx_types, currencies) do
      to_api_format(filtered_fees)
    else
      error -> handle_error(conn, error)
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

  defp to_api_format(fees) do
    fees
    |> Enum.map(&parse_for_type/1)
    |> Enum.into(%{})
    |> Response.serialize()
  end

  defp parse_for_type({tx_type, fees}) do
    {Integer.to_string(tx_type), Enum.map(fees, &parse_for_token/1)}
  end

  defp parse_for_token({currency, fee}) do
    %{
      currency: currency,
      amount: fee.amount,
      subunit_to_unit: fee.subunit_to_unit,
      pegged_currency: {:skip_hex_encode, fee.pegged_currency},
      pegged_amount: fee.pegged_amount,
      pegged_subunit_to_unit: fee.pegged_subunit_to_unit,
      updated_at: {:skip_hex_encode, fee.updated_at}
    }
  end

  defp handle_error(conn, {:error, {:validation_error, param_name, validator}}) do
    error = error_info(conn, :operation_bad_request)

    serialize_error(error.code, error.description, %{
      validation_error: %{parameter: param_name, validator: inspect(validator)}
    })
  end

  defp handle_error(conn, {:error, reason}) do
    error = error_info(conn, reason)

    serialize_error(error.code, error.description)
  end

  defp error_info(conn, reason) do
    case Map.get(@errors, reason) do
      nil -> %{code: "#{conn.path_info}#{inspect(reason)}", description: nil}
      error -> error
    end
  end

  @spec serialize_error(atom() | String.t(), String.t() | nil, map() | nil) :: map()
  defp serialize_error(code, description, messages \\ nil) do
    %{
      object: :error,
      code: code,
      description: description
    }
    |> add_messages(messages)
    |> Response.serialize()
  end

  defp add_messages(data, nil), do: data
  defp add_messages(data, messages), do: Map.put_new(data, :messages, messages)
end
