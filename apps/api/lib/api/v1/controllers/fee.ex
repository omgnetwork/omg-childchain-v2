defmodule API.V1.Controller.Fee do
  @moduledoc """
  Fetches fees and returns data for the API response.
  """

  alias API.V1.View.Fee
  alias Engine.Fees
  alias ExPlasma.Encoding

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
  def all(params) do
    with {:ok, currencies} <- to_binary(params["currencies"]),
         {:ok, filtered_fees} <- get_filtered_fees(params["tx_types"], currencies) do
      {:ok, Fee.serialize(filtered_fees)}
    else
      error -> %{}
    end
  end

  @spec get_filtered_fees(list(pos_integer()), list(String.t()) | nil) ::
          {:ok, Fees.full_fee_t()} | {:error, :currency_fee_not_supported}
  defp get_filtered_fees(tx_types, currencies) do
    {:ok, fees} = Fees.current_fees()

    Fees.filter(fees, tx_types, currencies)
  end

  defp to_binary(list, acc \\ [])

  defp to_binary(nil, _acc), do: {:ok, []}

  defp to_binary([value], acc) do
    case Encoding.to_binary(value) do
      {:ok, bin} -> {:ok, Enum.reverse([value | acc])}
      error -> error
    end
  end

  defp to_binary([value | tail], acc) do
    case Encoding.to_binary(value) do
      {:ok, binary} -> to_binary(tail, [binary | acc])
      error -> error
    end
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
  end

  defp add_messages(data, nil), do: data
  defp add_messages(data, messages), do: Map.put_new(data, :messages, messages)
end
