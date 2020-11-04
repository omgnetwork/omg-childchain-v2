defmodule Engine.DB.Transaction.PaymentV1.Validator.Witness do
  @moduledoc """
  Contains validation logic for signatures, see validate/2 for more details.
  """

  alias Engine.DB.Transaction.PaymentV1.Type
  alias ExPlasma.Crypto

  @type validation_result_t() ::
          :ok
          | {:error, {:witnesses, :superfluous_signature}}
          | {:error, {:witnesses, :missing_signature}}
          | {:error, {:witnesses, :unauthorized_spend}}

  @doc """
  Validates that the inputs `output_guard` match the recovered witnesses.
  Each input must have 1 signature, the witnesses order must match the inputs order.

  Returns
  - `:ok` if each input match their witness,
  or returns:
  - `{:error, {:witnesses, :superfluous_signature}}` if there are more witnesses than inputs
  - `{:error, {:witnesses, :missing_signature}}` if there are more inputs than witnesses
  - `{:error, {:witnesses, :unauthorized_spend}}` if one of the input doesn't have a matching witness

  ## Example:

  iex> Engine.DB.Transaction.PaymentV1.Validator.Witness.validate(
  ...> [%{output_guard: <<1::160>>, token: <<1::160>>, amount: 1},
  ...> %{output_guard: <<2::160>>, token: <<2::160>>, amount: 2}],
  ...> [<<1::160>>, <<2::160>>])
  :ok
  """
  @spec validate(Type.output_list_t(), list(Crypto.address_t())) :: validation_result_t()
  def validate(inputs, witnesses) do
    with :ok <- validate_length(inputs, witnesses),
         :ok <- validate_input_ownership(inputs, witnesses) do
      :ok
    end
  end

  defp validate_length(inputs, witnesses) when length(witnesses) > length(inputs) do
    {:error, {:witnesses, :superfluous_signature}}
  end

  defp validate_length(inputs, witnesses) when length(witnesses) < length(inputs) do
    {:error, {:witnesses, :missing_signature}}
  end

  defp validate_length(_inputs, _witnesses), do: :ok

  defp validate_input_ownership(inputs, witnesses) do
    inputs
    |> Enum.with_index()
    |> Enum.map(fn {input, index} -> can_spend?(input, Enum.at(witnesses, index)) end)
    |> Enum.all?()
    |> case do
      true -> :ok
      false -> {:error, {:witnesses, :unauthorized_spend}}
    end
  end

  defp can_spend?(%{output_guard: witness}, witness), do: true
  defp can_spend?(_output, _witness), do: false
end
