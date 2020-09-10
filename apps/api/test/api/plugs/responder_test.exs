defmodule API.Plugs.ResponderTest do
  use Engine.DB.DataCase, async: true
  use Plug.Test

  alias API.Plugs.Responder
  alias Plug.Conn

  setup do
    {:ok, %{conn: conn(:post, "/")}}
  end

  describe "call/2" do
    test "renders a json response with an error tuple containing a description", context do
      context.conn
      |> set_api_version("1.0")
      |> set_response({:error, :some_code, "some_description"})
      |> Responder.call([])

      assert {200, _headers, body} = sent_resp(context.conn)

      assert Jason.decode!(body) == %{
               "data" => %{"code" => "some_code", "description" => "some_description", "object" => "error"},
               "service_name" => "child_chain",
               "success" => false,
               "version" => "1.0"
             }
    end

    test "renders a json response with an error tuple with a known description", context do
      context.conn
      |> set_api_version("1.0")
      |> set_response({:error, :decoding_error})
      |> Responder.call([])

      assert {200, _headers, body} = sent_resp(context.conn)

      assert Jason.decode!(body) == %{
               "data" => %{
                 "code" => "decoding_error",
                 "description" => "Invalid hex encoded binary",
                 "object" => "error"
               },
               "service_name" => "child_chain",
               "success" => false,
               "version" => "1.0"
             }
    end

    test "renders a json response with an error tuple with an known description", context do
      context.conn
      |> set_api_version("1.0")
      |> set_response({:error, :qwerty})
      |> Responder.call([])

      assert {200, _headers, body} = sent_resp(context.conn)

      assert Jason.decode!(body) == %{
               "data" => %{
                 "code" => "qwerty",
                 "description" => "",
                 "object" => "error"
               },
               "service_name" => "child_chain",
               "success" => false,
               "version" => "1.0"
             }
    end

    test "renders a json response with some data", context do
      context.conn
      |> set_api_version("1.0")
      |> set_response({:ok, %{some: :data}})
      |> Responder.call([])

      assert {200, headers, body} = sent_resp(context.conn)

      assert {"content-type", "application/json; charset=utf-8"} in headers

      assert Jason.decode!(body) == %{
               "data" => %{"some" => "data"},
               "service_name" => "child_chain",
               "success" => true,
               "version" => "1.0"
             }
    end
  end

  defp set_api_version(conn, version), do: Conn.assign(conn, :api_version, version)
  defp set_response(conn, response), do: Conn.assign(conn, :response, response)
end
