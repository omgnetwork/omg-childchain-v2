defmodule Engine.DB.Transaction.PaymentV1.WitnessValidator do
  def validate(inputs, witnesses) do
    with :ok <- validate_length(inputs, witnesses),
         :ok <- validate_input_ownership(inputs, witnesses) do
      :ok
    end
  end

  defp validate_length(inputs, witnesses) when length(witnesses) > length(inputs) do
    {:error, {:inputs, :superfluous_signature}}
  end

  defp validate_length(inputs, witnesses) when length(witnesses) < length(inputs) do
    {:error, {:inputs, :missing_signature}}
  end

  defp validate_length(_inputs, _witnesses), do: :ok

  defp validate_input_ownership(inputs, witnesses) do
    inputs
    |> Enum.with_index()
    |> Enum.map(fn {input, index} -> can_spend?(input, Enum.at(witnesses, index)) end)
    |> Enum.all?()
    |> case do
      true -> :ok
      false -> {:error, {:inputs, :unauthorized_spend}}
    end
  end

  defp can_spend?(%{output_guard: owner}, witness), do: owner == witness
end
