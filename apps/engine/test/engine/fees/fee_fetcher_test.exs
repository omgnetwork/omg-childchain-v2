defmodule Engine.Fees.FeeFetcherTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Engine.Fees.FeeFetcher
  alias Engine.Fees.FeeFetcher.Client.JSONFeeParser
  alias FakeServer.Response

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

  @server_id :fees_all_fake_server

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
           fee_feed_url: "localhost:#{port}"
         ]
       }}
    end

    test "Updates fees fetched from feed when no fees previously set", %{initial_fees: fees, fee_adapter_opts: opts} do
      assert {:ok, ^fees} = FeeFetcher.get_fee_specs(opts, nil)
    end

    test "Does not update when fees has not changed in long time period", %{initial_fees: fees, fee_adapter_opts: opts} do
      assert :ok = FeeFetcher.get_fee_specs(opts, fees)
    end

    test "Does not update when fees changed within tolerance", %{
      initial_fees: fees,
      fee_adapter_opts: opts
    } do
      _ = update_feed_price(109)

      assert :ok = FeeFetcher.get_fee_specs(opts, fees)
    end

    test "Updates when fees changed above tolerance, although under update interval", %{
      initial_fees: fees,
      fee_adapter_opts: opts
    } do
      updated_fees = update_feed_price(110)
      assert {:ok, ^updated_fees} = FeeFetcher.get_fee_specs(opts, fees)
    end
  end

  defp make_fee_specs(amount), do: %{@payment_tx_type => %{@eth_hex => Map.put(@fee, :amount, amount)}}

  defp parse_specs(map), do: map |> Jason.encode!() |> JSONFeeParser.parse()

  defp get_current_fee_specs(),
    do: :current_fee_specs |> Agent.get(& &1) |> parse_specs()

  defp update_feed_price(amount) do
    Agent.update(:current_fee_specs, fn _ -> make_fee_specs(amount) end)
    {:ok, fees} = get_current_fee_specs()

    fees
  end

  defp fees_all_endpoint_setup(initial_price) do
    Agent.start(fn -> nil end, name: :current_fee_specs)

    path = "/fees"
    {:ok, pid} = FakeServer.start(@server_id)

    :ok =
      FakeServer.put_route(pid, path, fn _ ->
        fees = Agent.get(:current_fee_specs, & &1)

        ResponseFactory.build(:json_rpc, data: fees)
      end)

    {:ok, port} = FakeServer.port(@server_id)
    {update_feed_price(initial_price), port}
  end

  defp fees_all_endpoint_teardown() do
    FakeServer.stop(@server_id)

    Agent.stop(:current_fee_specs)
  end
end

defmodule ResponseFactory do
  @moduledoc false
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
