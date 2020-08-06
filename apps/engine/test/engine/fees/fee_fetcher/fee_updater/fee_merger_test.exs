defmodule Engine.Fees.FeeFetcher.FeeUpdater.FeeMergerTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Engine.Fees.FeeFetcher.FeeUpdater.FeeMerger

  doctest FeeMerger

  @eth <<0::160>>
  @not_eth <<1::size(160)>>

  @valid_current %{
    1 => %{
      @eth => %{
        amount: 1,
        subunit_to_unit: 1_000_000_000_000_000_000,
        pegged_amount: nil,
        pegged_currency: nil,
        pegged_subunit_to_unit: nil,
        updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
      },
      @not_eth => %{
        amount: 2,
        subunit_to_unit: 1_000_000_000_000_000_000,
        pegged_amount: nil,
        pegged_currency: nil,
        pegged_subunit_to_unit: nil,
        updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
      }
    }
  }

  @valid_previous %{
    1 => %{
      @eth => %{
        amount: 3,
        subunit_to_unit: 1_000_000_000_000_000_000,
        pegged_amount: nil,
        pegged_currency: nil,
        pegged_subunit_to_unit: nil,
        updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
      },
      @not_eth => %{
        amount: 4,
        subunit_to_unit: 1_000_000_000_000_000_000,
        pegged_amount: nil,
        pegged_currency: nil,
        pegged_subunit_to_unit: nil,
        updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
      }
    }
  }

  describe "merge_specs/2" do
    test "merges previous and current specs with distinct amounts" do
      assert %{1 => %{@eth => [1, 3], @not_eth => [2, 4]}} == FeeMerger.merge_specs(@valid_current, @valid_previous)
    end

    test "merges ignore amounts when they are the same" do
      previous =
        @valid_previous
        |> Kernel.put_in([1, @eth, :amount], 1)
        |> Kernel.put_in([1, @not_eth, :amount], 2)

      assert %{1 => %{@eth => [1], @not_eth => [2]}} == FeeMerger.merge_specs(@valid_current, previous)
    end

    test "merges correctly with nil previous" do
      assert %{1 => %{@eth => [1], @not_eth => [2]}} == FeeMerger.merge_specs(@valid_current, nil)
    end

    test "merges supports new tokens in previous" do
      new_token = <<2::size(160)>>

      new_token_fees = %{
        amount: 5,
        subunit_to_unit: 1_000_000_000_000_000_000,
        pegged_amount: nil,
        pegged_currency: nil,
        pegged_subunit_to_unit: nil,
        updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
      }

      previous = Kernel.put_in(@valid_previous, [1, new_token], new_token_fees)

      assert %{1 => %{@eth => [1, 3], @not_eth => [2, 4], new_token => [5]}} ==
               FeeMerger.merge_specs(@valid_current, previous)
    end

    test "merges supports new tokens in current" do
      new_token = <<2::size(160)>>

      new_token_fees = %{
        amount: 5,
        subunit_to_unit: 1_000_000_000_000_000_000,
        pegged_amount: nil,
        pegged_currency: nil,
        pegged_subunit_to_unit: nil,
        updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
      }

      current = Kernel.put_in(@valid_current, [1, new_token], new_token_fees)

      assert %{1 => %{@eth => [1, 3], @not_eth => [2, 4], new_token => [5]}} ==
               FeeMerger.merge_specs(current, @valid_previous)
    end

    test "merges supports new type in previous" do
      previous = Map.put(@valid_previous, 2, Map.get(@valid_previous, 1))

      assert %{1 => %{@eth => [1, 3], @not_eth => [2, 4]}, 2 => %{@eth => [3], @not_eth => [4]}} ==
               FeeMerger.merge_specs(@valid_current, previous)
    end

    test "merges supports new type in current" do
      current = Map.put(@valid_current, 2, Map.get(@valid_current, 1))

      assert %{1 => %{@eth => [1, 3], @not_eth => [2, 4]}, 2 => %{@eth => [1], @not_eth => [2]}} ==
               FeeMerger.merge_specs(current, @valid_previous)
    end
  end
end
