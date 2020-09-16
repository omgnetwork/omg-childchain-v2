defmodule API.ErrorEnhancer do
  @moduledoc """
  Contain functions that help to enhance error into a
  {:error, atom, string} format that suits API response.
  """

  @descriptions %{
    decoding_error: "Invalid hex encoded binary",
    operation_not_found: "The given operation is invalid",
    malformed_rlp: "The given RLP encoded bytes is malformed",
    unsupported_media_type_error: "Content-Type header must be set to application/json",
    unexpected_error: "An unexpected error occured",
    malformed_body: "Body is not a valid JSON.",
    request_too_large: "Request is too large",
    currency_fee_not_supported: "One or more of the given currencies are not supported as a fee-token",
    tx_type_not_supported: "One or more of the given transaction types are not supported",
    no_block_matching_hash: "No block matching the given hash"
  }

  def enhance({:error, %Ecto.Changeset{} = changeset}) do
    {key, {message, _}} = hd(changeset.errors)
    {:error, :validation_error, "#{key}: #{message}"}
  end

  def enhance({:error, code}) when is_atom(code) do
    {:error, code, Map.get(@descriptions, code, "")}
  end
end
