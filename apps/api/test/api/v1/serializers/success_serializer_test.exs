defmodule API.V1.Serializer.SuccessTest do
  @moduledoc """
  """

  use ExUnit.Case, async: true

  alias API.V1.Serializer.Success

  describe "serialize/1" do
    test "serializes data" do
      assert Success.serialize(%{some: :data}) == %{
               data: %{some: :data},
               service_name: "childchain",
               success: true,
               version: "1.0"
             }
    end
  end
end
