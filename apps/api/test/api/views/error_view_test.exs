defmodule API.View.ErrorTest do
  @moduledoc """
  """

  use ExUnit.Case, async: true

  alias API.View.Error

  describe "serialize/3" do
    test "serializes a code and description" do
      assert Error.serialize(:code, "description", "1.0") == %{
               data: %{code: :code, description: "description", object: "error"},
               service_name: "child_chain",
               success: false,
               version: "1.0"
             }
    end
  end
end
