defmodule API.Plugs.ExpectParams.ParamsValidator do
  @moduledoc """
  Contains validation logic for params.
  """

  def validate(conn_params, expected_params) do
    Enum.reduce_while(expected_params, {:ok, %{}}, fn param, {:ok, acc} ->
      with {:ok, value} <- validate_required(conn_params, param.name, param.required),
           {:ok, value} <- validate_value(value, param.name),
           :ok <- validate_format(value, param.type) do
        {:cont, {:ok, Map.put(acc, param.name, value)}}
      else
        error -> {:halt, error}
      end
    end)
  end

  defp validate_required(conn_params, param_name, true) when is_map_key(conn_params, param_name) do
    {:ok, Map.get(conn_params, param_name)}
  end

  defp validate_required(_, param_name, true) do
    {:error, :missing_required_param, "missing required key '#{param_name}'"}
  end

  defp validate_required(conn_params, param_name, false), do: {:ok, Map.get(conn_params, param_name)}

  defp validate_value(nil, _param_name), do: {:ok, nil}

  defp validate_value(param_value, param_name) do
    case scrub_param(param_value) do
      nil ->
        {:error, :invalid_param_value, "value for key '#{param_name}' is invalid, got: '#{param_value}'"}

      param ->
        {:ok, param}
    end
  end

  defp validate_format(nil, _format), do: :ok
  defp validate_format("0x" <> _, :hex), do: :ok
  defp validate_format(value, :non_neg_integer) when is_integer(value) and value > -1, do: :ok

  defp validate_format([value], {:list, format}) do
    validate_format(value, format)
  end

  defp validate_format([], {:list, _format}), do: :ok

  defp validate_format([value | tail], {:list, format}) do
    case validate_format(value, format) do
      :ok -> validate_format(tail, {:list, format})
      error -> error
    end
  end

  defp validate_format(params, {:list, _format}) do
    {:error, :invalid_param_type, "provided value is not a list, got: '#{params}'"}
  end

  defp validate_format(value, _) do
    {:error, :invalid_param_type, "hex values must be prefixed with 0x, got: '#{value}'"}
  end

  defp scrub_param(%{} = param) do
    Enum.reduce(param, %{}, fn {k, v}, acc ->
      Map.put(acc, k, scrub_param(v))
    end)
  end

  defp scrub_param(param) when is_list(param) do
    Enum.map(param, &scrub_param/1)
  end

  defp scrub_param(param) do
    if scrub?(param), do: nil, else: param
  end

  defp scrub?(" " <> rest), do: scrub?(rest)
  defp scrub?(""), do: true
  defp scrub?(_), do: false
end
