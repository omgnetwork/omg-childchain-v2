defmodule API.Plugs.ExpectParams do
  @moduledoc """
  Checks that a request has the expected params, otherwise raise an error. Here are the options:

  * :path - Specify the `path` you want this to check. like `path: "/foo"
  * :key  - Specify the `conn.params` key you want to check, `key: "hash"`
  * :hex  - Check that the specified key is a string prefixed with `0x`.

  To use in your pipeline you can just:

  plug ExpectParams, key: "foo", path: "/bar", hex: false

  Leverages the scrub_params/2 code from Phoenix.
  """

  alias __MODULE__.InvalidParams

  def init(options), do: options

  def call(conn, opts) do
    if conn.request_path == opts[:path] do
      conn |> scrub_params(opts[:key]) |> validate_hex(opts[:key], opts[:hex])
    else
      conn
    end
  end

  defp validate_hex(conn, required_key, true) when is_binary(required_key) do
    if conn.params |> Map.get(required_key) |> is_hex?() do
      conn
    else
      raise InvalidParams, "#{required_key} must be prefixed with \"0x\""
    end
  end

  defp validate_hex(conn, _required_key, _), do: conn

  defp is_hex?("0x" <> _), do: true
  defp is_hex?(_), do: false

  defp scrub_params(conn, required_key) when is_binary(required_key) do
    param = conn.params |> Map.get(required_key) |> scrub_param()

    unless param do
      raise InvalidParams, "missing required key \"#{required_key}\""
    end

    params = Map.put(conn.params, required_key, param)
    %Plug.Conn{conn | params: params}
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

  defmodule InvalidParams do
    defexception [:message]
  end
end
