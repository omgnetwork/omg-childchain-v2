defmodule Engine.BlockFormation.PrepareForSubmission.CoreTest do
  use ExUnit.Case, async: true

  alias Engine.BlockFormation.PrepareForSubmission.Core

  describe "should_finalize_block?/3" do
    test "returns true if enough Ethereum blocks were mined since the last finalization" do
      assert Core.should_finalize_block?(2, 1, 1)
      assert Core.should_finalize_block?(4, 2, 2)
    end

    test "returns false if not enough Ethereum blocks were mined since the last finalization" do
      refute Core.should_finalize_block?(2, 1, 2)
      refute Core.should_finalize_block?(2, 2, 1)
    end
  end
end
