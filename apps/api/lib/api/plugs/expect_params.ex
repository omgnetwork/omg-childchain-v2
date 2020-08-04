defmodule API.Plugs.ExpectParams do
  @moduledoc """
  Checks that a request has the expected params.
  Returns the conn with filtered params, removing any unwanted param, if success
  or responds with an error otherwise.

  Leverages the scrub_params/2 code from Phoenix.
  """

  alias __MODULE__.ValidateParams

  def init(options), do: options

  def call(conn, opts) do
    expected_params = Keyword.fetch!(opts, :expected_params)
    responder = Keyword.fetch!(opts, :responder)
    unversioned_path = get_path(conn)

    with path_params when is_list(path_params) <- Map.get(expected_params, unversioned_path, :path_not_found),
         {:ok, params} <- ValidateParams.validate(conn.params, path_params) do
      %{conn | params: params}
    else
      :path_not_found ->
        conn

      error ->
        responder.respond(conn, error)
    end
  end

  defp get_path(conn), do: Enum.join(conn.path_info, "/")
end
