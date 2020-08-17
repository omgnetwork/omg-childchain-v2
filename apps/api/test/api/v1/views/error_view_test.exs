defmodule API.V1.View.ErrorTest do
  @moduledoc """
  """

  use ExUnit.Case, async: true

  alias API.V1.View.Error

  describe "serialize/1" do
    test "serializes a tuple of errors" do
      assert Error.serialize({:error, :code, "description"}) == %{
               data: %{code: :code, description: "description", object: "error"},
               service_name: "childchain",
               success: false,
               version: "1.0"
             }
    end

    test "serializes a code and description" do
      assert Error.serialize(:code, "description") == %{
               data: %{code: :code, description: "description", object: "error"},
               service_name: "childchain",
               success: false,
               version: "1.0"
             }
    end
  end
end
