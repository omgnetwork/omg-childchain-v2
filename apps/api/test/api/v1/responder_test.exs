defmodule API.V1.ResponderTest do
  use Engine.DB.DataCase, async: true
  use Plug.Test

  alias API.V1.Responder

  setup do
    {:ok, %{conn: conn(:post, "/")}}
  end

  describe "respond/2" do
    test "renders a v1 json response with an error tuple containing a description", context do
      Responder.respond(context.conn, {:error, :some_code, "some_description"})
      assert {200, _headers, body} = sent_resp(context.conn)

      assert Jason.decode!(body) == %{
               "data" => %{"code" => "some_code", "description" => "some_description", "object" => "error"},
               "service_name" => "childchain",
               "success" => false,
               "version" => "1.0"
             }
    end

    test "renders a v1 json response with an error tuple with a known description", context do
      Responder.respond(context.conn, {:error, :decoding_error})
      assert {200, _headers, body} = sent_resp(context.conn)

      assert Jason.decode!(body) == %{
               "data" => %{
                 "code" => "decoding_error",
                 "description" => "Invalid hex encoded binary",
                 "object" => "error"
               },
               "service_name" => "childchain",
               "success" => false,
               "version" => "1.0"
             }
    end

    test "renders a v1 json response with an error tuple with an known description", context do
      Responder.respond(context.conn, {:error, :qwerty})
      assert {200, _headers, body} = sent_resp(context.conn)

      assert Jason.decode!(body) == %{
               "data" => %{
                 "code" => "qwerty",
                 "description" => "",
                 "object" => "error"
               },
               "service_name" => "childchain",
               "success" => false,
               "version" => "1.0"
             }
    end

    test "renders a v1 json response with some data", context do
      Responder.respond(context.conn, {:ok, %{some: :data}})
      assert {200, _headers, body} = sent_resp(context.conn)

      assert Jason.decode!(body) == %{
               "data" => %{"some" => "data"},
               "service_name" => "childchain",
               "success" => true,
               "version" => "1.0"
             }
    end
  end
end
