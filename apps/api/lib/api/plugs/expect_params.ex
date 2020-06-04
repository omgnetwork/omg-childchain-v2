defmodule API.Plugs.ExpectParams do
  @moduledoc """
  Checks that a request has the expected params, otherwise raise an error.

  Leverages the scrub_params/2 code from Phoenix.
  """

  alias API.Plugs.ExpectParams.MissingParamsError

  def init(options), do: options

  def call(conn, opts) do
    if conn.request_path == opts[:path] do
      scrub_params(conn, opts[:key])
    else
      conn
    end
  end

  defp scrub_params(conn, required_key) when is_binary(required_key) do
    param = conn.params |> Map.get(required_key) |> scrub_param()

    unless param do
      raise MissingParamsError, key: required_key
    end

    params = Map.put(conn.params, required_key, param)
    %Plug.Conn{conn | params: params}
  end

  defp scrub_param(%{__struct__: mod} = struct) when is_atom(mod) do
    struct
  end

  defp scrub_param(%{} = param) do
    Enum.reduce(param, %{}, fn({k, v}, acc) ->
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

defmodule API.Plugs.ExpectParams.MissingParamsError do
  defexception [:message, :key, :plug_status]

  @impl true
  def exception(key: key) do
    msg = "Expected param key #{inspect(key)} but was not found"
    %__MODULE__{message: msg, key: key, plug_status: 400}
  end
end
