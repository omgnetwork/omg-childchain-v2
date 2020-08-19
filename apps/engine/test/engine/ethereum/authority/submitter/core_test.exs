defmodule Engine.Ethereum.Authority.Submitter.CoreTest do
  use ExUnit.Case, async: true
  alias Engine.Ethereum.Authority.Submitter.Core

  test "the last mined block is the difference between the next childblock minus the interval" do
    assert Core.mined(1000, 1000) == 0
    assert Core.mined(2000, 1000) == 1000
    assert Core.mined(1_200_000_000_000, 1_199_999_999_000) == 1000
  end
end
