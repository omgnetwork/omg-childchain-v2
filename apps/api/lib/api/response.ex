defmodule API.Response do
  @moduledoc """
  Serializes the response into expected result/data format.
  """

  @sha String.replace(elem(System.cmd("git", ["rev-parse", "--short=7", "HEAD"]), 0), "\n", "")

  @type response_t :: %{version: binary(), success: boolean(), data: map()}

  def serialize_page(data, data_paging) do
    data
    |> serialize()
    |> Map.put(:data_paging, data_paging)
  end

  @doc """
  Append result of operation to the response data forming standard api response structure
  """
  @spec serialize(any()) :: response_t()
  def serialize(%{object: :error} = error) do
    to_response(error, :error)
  end

  def serialize(data) do
    data
    |> sanitize()
    |> to_response(:success)
  end

  @doc """
  Removes or encodes fields in response that cannot be serialized to api response.
  By default, it:
   * encodes to hex all binary values
   * removes metadata fields
  Provides standard data structure for API response
  """
  @spec sanitize(any()) :: any()
  def sanitize(response)

  # serialize all DateTimes to ISO8601 formatted strings
  def sanitize(%DateTime{} = datetime) do
    datetime |> DateTime.truncate(:second) |> DateTime.to_iso8601()
  end

  def sanitize(list) when is_list(list) do
    list |> Enum.map(&sanitize/1)
  end

  def sanitize(map_or_struct) when is_map(map_or_struct) do
    map_or_struct
    |> to_map()
    |> do_filter()
    |> sanitize_map()
  end

  def sanitize(bin) when is_binary(bin), do: to_hex(bin)
  def sanitize({:skip_hex_encode, bin}), do: bin
  def sanitize({{key, value}, _}), do: Map.put_new(%{}, key, value)
  def sanitize({key, value}), do: Map.put_new(%{}, key, value)
  def sanitize(value), do: value

  @spec to_hex(binary | non_neg_integer) :: binary
  def to_hex(non_hex)

  def to_hex(raw) when is_binary(raw), do: "0x" <> Base.encode16(raw, case: :lower)
  def to_hex(int) when is_integer(int), do: "0x" <> Integer.to_string(int, 16)

  @doc """
  Derive the running service's version for adding to a response.
  """
  @spec version(Application.app()) :: String.t()
  def version(app) do
    {:ok, vsn} = :application.get_key(app, :vsn)
    List.to_string(vsn) <> "+" <> @sha
  end

  defp do_filter(map_or_struct) do
    if :code.is_loaded(Ecto) do
      Enum.filter(map_or_struct, fn
        {_, %{__struct__: Ecto.Association.NotLoaded}} -> false
        _ -> true
      end)
      |> Map.new()
    else
      map_or_struct
    end
  end

  # Allows to skip sanitize on specifies keys provided in list in key :skip_hex_encode
  defp sanitize_map(map) do
    {skip_keys, map} = Map.pop(map, :skip_hex_encode, [])
    skip_keys = MapSet.new(skip_keys)

    map
    |> Enum.map(fn {k, v} ->
      case MapSet.member?(skip_keys, k) do
        true -> {k, v}
        false -> {k, sanitize(v)}
      end
    end)
    |> Map.new()
  end

  defp to_map(struct), do: Map.drop(struct, [:__struct__, :__meta__])

  defp to_response(data, result) do
    %{
      success: result == :success,
      data: data
    }
  end
end