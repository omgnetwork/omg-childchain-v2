defmodule API.Plugs.ExpectParams do
  @moduledoc """
  Checks that a request has the expected params.
  Returns the conn with filtered params, removing any unwanted param, if success
  or assigns an error to the :response key otherwise.

  * :expected_params is a map of path to params, like:

    %{
      "POST:block.get" => [
        %{name: "hash", type: :hex, required: true}
      ],
      "POST:transaction.submit" => [
        %{name: "transaction", type: :hex, required: true}
      ]
    }

  Leverages the scrub_params/2 code from Phoenix.
  """

  alias __MODULE__.ParamsValidator
  alias Plug.Conn

  def init(expected_params), do: expected_params

  def call(conn, expected_params) do
    unversioned_path = get_path(conn)

    with path_params when is_list(path_params) <- Map.get(expected_params, unversioned_path, :path_not_found),
         {:ok, params} <- ParamsValidator.validate(conn.params, path_params) do
      %{conn | params: params}
    else
      :path_not_found ->
        conn

      error ->
        Conn.assign(conn, :response, error)
    end
  end

  defp get_path(conn), do: conn.method <> ":" <> Enum.join(conn.path_info, "/")
end
