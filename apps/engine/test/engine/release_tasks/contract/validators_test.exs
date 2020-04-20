defmodule Engine.ReleaseTasks.Contract.ValidatorsTest do
  use ExUnit.Case, async: true

  alias Engine.ReleaseTasks.Contract.Validators

  describe "address/2" do
    test "that a valid address returns the same address" do
      assert Validators.address!("0xc673e4ffcb8464faff908a6804fe0e635af0ea2f", "key") ==
               "0xc673e4ffcb8464faff908a6804fe0e635af0ea2f"
    end

    test "that an unvalid address exits with argument error" do
      key = "key"

      assert catch_error(Validators.address!("yolo", key)) == %ArgumentError{
               message: "#{key} must be set to a valid Ethereum address."
             }
    end
  end

  describe "tx_hash/2" do
    test "that a valid transaction hash returns the same transaction hash" do
      assert Validators.tx_hash!("0xb836b6c4eb016e430b8e7495db92357896c1da263c6a3de73320b669eb5912d3", "key") ==
               "0xb836b6c4eb016e430b8e7495db92357896c1da263c6a3de73320b669eb5912d3"
    end

    test "that an unvalid transaction hash exits with argument error" do
      key = "key"

      assert catch_error(Validators.tx_hash!("yolo", key)) == %ArgumentError{
               message: "#{key} must be set to a valid Ethereum transaction hash."
             }
    end
  end
end
