defmodule API.RouterTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias API.Router

  test "renders an error when not matching a supported version" do
    {:ok, payload} =
      :post
      |> conn("foo")
      |> Router.call(Router.init([]))
      |> Map.get(:resp_body)
      |> Jason.decode()

    assert payload == %{
             "data" => %{
               "code" => "operation_not_found",
               "description" => "The given operation is invalid",
               "object" => "error"
             },
             "service_name" => "child_chain",
             "success" => false,
             "version" => "-"
           }
  end
end
