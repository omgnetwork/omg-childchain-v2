defmodule API.ResponderTest do
  use Engine.DB.DataCase, async: true
  use Plug.Test

  alias API.Responder

  setup do
    {:ok, %{conn: conn(:post, "/")}}
  end

  describe "render_json/2" do
    test "renders a json response with the given data", context do
      Responder.render_json(context.conn, %{some: :data})

      assert {200, headers, body} = sent_resp(context.conn)
      assert {"content-type", "application/json; charset=utf-8"} in headers
      assert Jason.decode!(body) == %{"some" => "data"}
    end
  end
end
