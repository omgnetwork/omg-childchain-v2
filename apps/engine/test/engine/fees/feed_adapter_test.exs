defmodule OMG.ChildChain.Fees.FeedAdapterTest do
  @moduledoc false

  use ExUnitFixtures
  use ExUnit.Case, async: true

  alias Engine.Fees.FeedAdapter
  alias Engine.Fees.JSONFeeParser
  alias FakeServer.Agents.EnvAgent
  alias FakeServer.Env
  alias FakeServer.HTTP.Response
  alias FakeServer.HTTP.Server

  @moduletag :child_chain

  @server_id :fees_all_fake_server

  @eth <<0::160>>
  @eth_hex "0x" <> Base.encode16(<<0::160>>, case: :lower)
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
    setup do
      {initial_fees, port} = fees_all_endpoint_setup(@initial_price)

      on_exit(fn ->
        fees_all_endpoint_teardown()
      end)

      {:ok,
       %{
         initial_fees: initial_fees,
         actual_updated_at: :os.system_time(:second),
         after_period_updated_at: :os.system_time(:second) - 5 * 60 - 1,
         fee_adapter_opts: [
           fee_change_tolerance_percent: 10,
           stored_fee_update_interval_minutes: 5,
           fee_feed_url: "localhost:#{port}"
         ]
       }}
    end

    test "Updates fees fetched from feed when no fees previously set", %{initial_fees: fees, fee_adapter_opts: opts} do
      assert {:ok, ^fees, _ts} = FeedAdapter.get_fee_specs(opts, nil, 0)
    end

    test "Does not update when fees has not changed in long time period", %{initial_fees: fees, fee_adapter_opts: opts} do
      assert :ok = FeedAdapter.get_fee_specs(opts, fees, 0)
    end

    test "Does not update when fees changed within tolerance", %{
      initial_fees: fees,
      actual_updated_at: updated_at,
      fee_adapter_opts: opts
    } do
      _ = update_feed_price(109)
      assert :ok = FeedAdapter.get_fee_specs(opts, fees, updated_at)
    end

    test "Updates when fees changed above tolerance, although under update interval", %{
      initial_fees: fees,
      actual_updated_at: updated_at,
      fee_adapter_opts: opts
    } do
      updated_fees = update_feed_price(110)
      assert {:ok, ^updated_fees, _ts} = FeedAdapter.get_fee_specs(opts, fees, updated_at)
    end

    test "Updates when fees changed below tolerance level, but exceeds update interval", %{
      initial_fees: fees,
      after_period_updated_at: long_ago,
      fee_adapter_opts: opts
    } do
      updated_fees = update_feed_price(109)
      assert {:ok, ^updated_fees, _ts} = FeedAdapter.get_fee_specs(opts, fees, long_ago)
    end
  end

  defp make_fee_specs(amount), do: %{@payment_tx_type => %{@eth_hex => Map.put(@fee, :amount, amount)}}

  defp parse_specs(map), do: map |> Jason.encode!() |> JSONFeeParser.parse()

  defp get_current_fee_specs(),
    do: :current_fee_specs |> Agent.get(& &1) |> parse_specs()

  defp make_response(data) do
    Jason.encode!(%{
      version: "1.0",
      success: true,
      data: data
    })
  end

  defp update_feed_price(amount) do
    Agent.update(:current_fee_specs, fn _ -> make_fee_specs(amount) end)
    {:ok, fees} = get_current_fee_specs()

    fees
  end

  defp fees_all_endpoint_setup(initial_price) do
    Agent.start(fn -> nil end, name: :current_fee_specs)

    path = "/fees"
    {:ok, @server_id, port} = Server.run(%{id: @server_id})
    env = %FakeServer.Env{Env.new(port) | routes: [path]}
    EnvAgent.save_env(@server_id, env)

    Server.add_response(@server_id, path, fn _ ->
      headers = %{"content-type" => "application/json"}

      :current_fee_specs
      |> Agent.get(& &1)
      |> make_response()
      |> Response.ok(headers)
    end)

    {update_feed_price(initial_price), port}
  end

  defp fees_all_endpoint_teardown() do
    :ok = Server.stop(@server_id)
    EnvAgent.delete_env(@server_id)

    Agent.stop(:current_fee_specs)
  end
end
