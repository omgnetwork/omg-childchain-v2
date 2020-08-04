defmodule API.V1.ErrorEnhancerTest do
  use ExUnit.Case, async: true
  alias API.V1.ErrorEnhancer

  describe "enhance/1" do
    test "enhance a changeset error" do
      changeset = Ecto.Changeset.add_error(%Ecto.Changeset{}, :some_key, "some_error")

      assert ErrorEnhancer.enhance({:error, changeset}) == {:error, :validation_error, "some_key: some_error"}
    end

    test "enhance a tuple of errors with a known error" do
      assert ErrorEnhancer.enhance({:error, :decoding_error}) == {:error, :decoding_error, "Invalid hex encoded binary"}
    end

    test "enhance a tuple of errors with a unknown error" do
      assert ErrorEnhancer.enhance({:error, :unknown_key}) == {:error, :unknown_key, ""}
    end
  end
end
