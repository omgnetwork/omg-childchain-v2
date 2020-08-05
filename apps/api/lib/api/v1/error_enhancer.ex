defmodule API.V1.ErrorEnhancer do
  @moduledoc """
  Contain functions that help to enhance error into a
  {:error, atom, string} format that suits API response.
  """

  @descriptions %{
    decoding_error: "Invalid hex encoded binary",
    operation_not_found: "The given operation is invalid",
    malformed_rlp: "The given RLP encoded bytes is malformed"
  }

  def enhance({:error, %Ecto.Changeset{} = changeset}) do
    {key, {message, _}} = hd(changeset.errors)
    {:error, :validation_error, "#{key}: #{message}"}
  end

  def enhance({:error, code}) when is_atom(code) do
    {:error, code, Map.get(@descriptions, code, "")}
  end
end
