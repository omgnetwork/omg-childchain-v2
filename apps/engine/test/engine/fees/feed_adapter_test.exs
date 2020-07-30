defmodule Engine.Fees.FeedAdapterTest do
  @moduledoc false

  use ExUnitFixtures
  use ExUnit.Case, async: true

  import FakeServer

  alias Engine.Fees.FeedAdapter
  alias Engine.Fees.JSONFeeParser
  alias FakeServer.Response

  @moduletag :child_chain

  @eth <<0::160>>
  @eth_hex "0x" <> Base.encode16(@eth, case: :lower)
  @payment_tx_type 1

  @initial_price 100
  @fee %{
    amount: @initial_price,
    pegged_amount: 1,
    subunit_to_unit: 1_000_000_000_000_000_000,
    pegged_currency: "USD",
    pegged_subunit_to_unit: 100,
    updated_at: DateTime.from_unix!(1_546_336_800),
    symbol: "ETH",
    type: :fixed
  }

  describe "get_fee_specs/2" do
    test_with_server "Updates fees fetched from feed when no fees previously set" do
      initial_fees = make_fee_specs(@initial_price)
      customized_response = ResponseFactory.build(:json_rpc, data: initial_fees)
      route("/fees", customized_response)
      opts = fee_adapter_opts(FakeServer.address())

      {:ok, expected_fees} = parse_specs(initial_fees)

      assert {:ok, ^expected_fees, _} = FeedAdapter.get_fee_specs(opts, nil, 0)
    end

    test_with_server "Does not update when fees has not changed in long time period" do
      initial_fees = make_fee_specs(@initial_price)
      customized_response = ResponseFactory.build(:json_rpc, data: initial_fees)
      route("/fees", customized_response)
      opts = fee_adapter_opts(FakeServer.address())

      {:ok, fees} = parse_specs(initial_fees)

      assert :ok = FeedAdapter.get_fee_specs(opts, fees, 0)
    end

    test_with_server "Does not update when fees changed within tolerance" do
      updated_at = :os.system_time(:second)
      initial_fees = make_fee_specs(@initial_price)
      new_fees = make_fee_specs(109)
      customized_response = ResponseFactory.build(:json_rpc, data: new_fees)
      route("/fees", customized_response)
      opts = fee_adapter_opts(FakeServer.address())

      {:ok, fees} = parse_specs(initial_fees)

      assert :ok = FeedAdapter.get_fee_specs(opts, fees, updated_at)
    end

    test_with_server "Updates when fees changed above tolerance, although under update interval" do
      updated_at = :os.system_time(:second)
      initial_fees = make_fee_specs(@initial_price)
      new_fees = make_fee_specs(110)
      customized_response = ResponseFactory.build(:json_rpc, data: new_fees)
      route("/fees", customized_response)
      opts = fee_adapter_opts(FakeServer.address())

      {:ok, fees} = parse_specs(initial_fees)
      {:ok, updated_fees} = parse_specs(new_fees)

      assert {:ok, ^updated_fees, _} = FeedAdapter.get_fee_specs(opts, fees, updated_at)
    end

    test_with_server "Updates when fees changed below tolerance level, but exceeds update interval" do
      updated_at = :os.system_time(:second) - 5 * 60 - 1
      initial_fees = make_fee_specs(@initial_price)
      new_fees = make_fee_specs(109)
      customized_response = ResponseFactory.build(:json_rpc, data: new_fees)
      route("/fees", customized_response)
      opts = fee_adapter_opts(FakeServer.address())

      {:ok, fees} = parse_specs(initial_fees)
      {:ok, updated_fees} = parse_specs(new_fees)

      assert {:ok, ^updated_fees, _} = FeedAdapter.get_fee_specs(opts, fees, updated_at)
    end
  end

  defp make_fee_specs(amount), do: %{@payment_tx_type => %{@eth_hex => Map.put(@fee, :amount, amount)}}

  defp fee_adapter_opts(fee_feed_url) do
    [
      fee_change_tolerance_percent: 10,
      stored_fee_update_interval_minutes: 5,
      fee_feed_url: fee_feed_url
    ]
  end

  defp parse_specs(map), do: map |> Jason.encode!() |> JSONFeeParser.parse()
end

defmodule ResponseFactory do
  use FakeServer.ResponseFactory

  def json_rpc_response() do
    ok(
      %{
        version: "1.0",
        success: true,
        data: %{}
      },
      %{"Content-Type" => "application/json"}
    )
  end
end
