defmodule API.View.BaseTest do
  @moduledoc """
  """

  use ExUnit.Case, async: true

  alias API.View.Base

  describe "serialize/3" do
    test "serializes data, success and version" do
      assert Base.serialize(%{some: "data"}, true, "1.2.3") == %{
               data: %{some: "data"},
               service_name: "childchain",
               success: true,
               version: "1.2.3"
             }
    end
  end
end
