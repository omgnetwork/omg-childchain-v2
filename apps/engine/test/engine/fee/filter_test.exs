defmodule Engine.Fee.FilterTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Engine.Fee.Filter

  doctest Engine.Fee.Filter

  @eth <<0::160>>
  @not_eth_1 <<1::size(160)>>
  @not_eth_2 <<2::size(160)>>
  @payment_tx_type 1

  @payment_fees %{
    @eth => %{
      amount: 1,
      subunit_to_unit: 1_000_000_000_000_000_000,
      pegged_amount: 4,
      pegged_currency: "USD",
      pegged_subunit_to_unit: 100,
      updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
    },
    @not_eth_1 => %{
      amount: 3,
      subunit_to_unit: 1000,
      pegged_amount: 4,
      pegged_currency: "USD",
      pegged_subunit_to_unit: 100,
      updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
    }
  }

  @fees %{
    @payment_tx_type => @payment_fees,
    2 => @payment_fees,
    3 => %{
      @not_eth_2 => %{
        amount: 3,
        subunit_to_unit: 1000,
        pegged_amount: 4,
        pegged_currency: "USD",
        pegged_subunit_to_unit: 100,
        updated_at: DateTime.from_iso8601("2019-01-01T10:10:00+00:00")
      }
    }
  }

  describe "filter/2" do
    test "does not filter tx_type when given an empty list" do
      assert Filter.filter(@fees, [], []) == {:ok, @fees}
    end

    test "does not filter tx_type when given a nil value" do
      assert Filter.filter(@fees, nil, []) == {:ok, @fees}
    end

    test "does not filter currencies when given an empty list" do
      assert Filter.filter(@fees, [], []) == {:ok, @fees}
    end

    test "does not filter currencies when given a nil value" do
      assert Filter.filter(@fees, [], nil) == {:ok, @fees}
    end

    test "filter fees by currency given a list of currencies" do
      assert Filter.filter(@fees, [], [@eth]) ==
               {:ok,
                %{
                  @payment_tx_type => Map.take(@payment_fees, [@eth]),
                  2 => Map.take(@payment_fees, [@eth]),
                  3 => %{}
                }}

      assert Filter.filter(@fees, [], [@not_eth_2]) == {:ok, %{@payment_tx_type => %{}, 2 => %{}, 3 => @fees[3]}}
    end

    test "filter fees by tx_type when given a list of tx_types" do
      assert Filter.filter(@fees, [1, 2], []) == {:ok, Map.drop(@fees, [3])}
    end

    test "filter fees by both tx_type and currencies" do
      assert Filter.filter(@fees, [1, 2], [@eth]) ==
               {:ok,
                %{
                  @payment_tx_type => Map.take(@payment_fees, [@eth]),
                  2 => Map.take(@payment_fees, [@eth])
                }}
    end

    test "returns an error when given an unsupported currency" do
      other_token = <<9::160>>
      assert Filter.filter(@fees, [], [other_token]) == {:error, :currency_fee_not_supported}
    end

    test "returns an error when given an unsupported tx_type" do
      tx_type = 99_999
      assert Filter.filter(@fees, [tx_type], []) == {:error, :tx_type_not_supported}
    end
  end
end
