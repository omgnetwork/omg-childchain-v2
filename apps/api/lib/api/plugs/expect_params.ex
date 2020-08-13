defmodule API.Plugs.ExpectParams do
  @moduledoc """
  Checks that a request has the expected params.
  Returns the conn with filtered params, removing any unwanted param, if success
  or responds with an error otherwise.

  Here are the required options:
  * :expected_params - A map of path to params, like:

    %{
      "POST:block.get" => [
        %{name: "hash", type: :hex, required: true}
      ],
      "POST:transaction.submit" => [
        %{name: "transaction", type: :hex, required: true}
      ]
    }
  * :responder - A responder conforming to the `API.Responder` behaviour.

  Leverages the scrub_params/2 code from Phoenix.
  """

  alias __MODULE__.ParamsValidator

  def init(options), do: options

  def call(conn, opts) do
    expected_params = Keyword.fetch!(opts, :expected_params)
    responder = Keyword.fetch!(opts, :responder)
    unversioned_path = get_path(conn)

    with path_params when is_list(path_params) <- Map.get(expected_params, unversioned_path, :path_not_found),
         {:ok, params} <- ParamsValidator.validate(conn.params, path_params) do
      %{conn | params: params}
    else
      :path_not_found ->
        conn

      error ->
        responder.respond(conn, error)
    end
  end

  defp get_path(conn), do: conn.method <> ":" <> Enum.join(conn.path_info, "/")
end
