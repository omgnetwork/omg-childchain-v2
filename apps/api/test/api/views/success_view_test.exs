defmodule API.View.SuccessTest do
  @moduledoc """
  """

  use ExUnit.Case, async: true

  alias API.View.Success

  describe "serialize/2" do
    test "serializes data" do
      assert Success.serialize(%{some: :data}, "1.0") == %{
               data: %{some: :data},
               service_name: "child_chain",
               success: true,
               version: "1.0"
             }
    end
  end
end
