defmodule Engine.DB.Transaction.PaymentV1.MergeValidator do
  @moduledoc """
  Decides whether transactions qualify as "merge" transactions that use a single currency,
  single recipient address and have fewer outputs than inputs. This decision is necessary
  to know by the child chain to not require the transaction fees.
  """

  alias Engine.DB.Transaction.PaymentV1.Type

  @doc """
  Decides whether the given input and ouput data qualify as "merge".

  To be a "merge" we must:
  - Have the same `output_guard` for all inputs and outputs
  - Have the same `token` for all inputs and outputs
  - Have less outputs than inputs

  Returns `true` if the transaction is a merge, or `false` otherwise.

  ## Example:

  iex> Engine.DB.Transaction.PaymentV1.MergeValidator.is_merge?([
  ...> %{output_guard: <<1::160>>, token: <<1::160>>, amount: 1 },
  ...> %{output_guard: <<1::160>>, token: <<1::160>>, amount: 2}], [
  ...> %{output_guard: <<1::160>>, token: <<1::160>>, amount: 3}])
  true
  """
  @spec is_merge?(Type.output_list_t(), Type.output_list_t()) :: boolean()
  def is_merge?(input_data, output_data) do
    with true <- has_same?(input_data, output_data, :output_guard),
         true <- has_same?(input_data, output_data, :token),
         true <- has_less_outputs_than_inputs?(input_data, output_data) do
      true
    end
  end

  defp has_same?(input_data, output_data, element) do
    input_elements = Enum.map(input_data, & &1[element])
    output_elements = Enum.map(output_data, & &1[element])

    input_elements
    |> Enum.concat(output_elements)
    |> single?()
  end

  defp has_less_outputs_than_inputs?(inputs, outputs), do: length(inputs) >= 1 and length(inputs) > length(outputs)

  defp single?(list), do: list |> Enum.uniq() |> length() == 1
end
