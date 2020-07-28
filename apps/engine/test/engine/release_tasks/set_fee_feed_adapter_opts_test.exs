defmodule Engine.ReleaseTasks.SetFeeFeedAdapterOptsTest do
  use ExUnit.Case, async: true
  alias Engine.Fees.FeedAdapter
  alias Engine.ReleaseTasks.SetFeeFeedAdapterOpts

  @app :omg_child_chain
  @config_key :fee_adapter
  @env_fee_adapter "FEE_ADAPTER"
  @env_fee_feed_url "FEE_FEED_URL"
  @env_fee_change_tolerance_percent "FEE_CHANGE_TOLERANCE_PERCENT"
  @env_stored_fee_update_interval_minutes "STORED_FEE_UPDATE_INTERVAL_MINUTES"

  setup do
    original_config = Application.get_all_env(@app)

    on_exit(fn ->
      # Delete all related env vars
      :ok = System.delete_env(@env_fee_adapter)
      :ok = System.delete_env(@env_fee_feed_url)
      :ok = System.delete_env(@env_fee_change_tolerance_percent)
      :ok = System.delete_env(@env_stored_fee_update_interval_minutes)

      # configuration is global state so we reset it to known values in case it got fiddled before
      :ok = Enum.each(original_config, fn {key, value} -> Application.put_env(@app, key, value, persistent: true) end)
    end)

    :ok
  end

  test "sets the fee adapter to FeedAdapter and configure with its related env vars" do
    :ok = System.put_env(@env_fee_adapter, "feed")
    :ok = System.put_env(@env_fee_feed_url, "http://example.com/fee-feed-url")
    :ok = System.put_env(@env_fee_change_tolerance_percent, "10")
    :ok = System.put_env(@env_stored_fee_update_interval_minutes, "600")
    config = SetFeeFeedAdapterOpts.load([], [])

    {adapter, opts: adapter_opts} = config[@app][@config_key]
    assert adapter == FeedAdapter
    assert adapter_opts[:fee_feed_url] == "http://example.com/fee-feed-url"
    assert adapter_opts[:fee_change_tolerance_percent] == 10
    assert adapter_opts[:stored_fee_update_interval_minutes] == 600
  end

  test "raises an ArgumentError when FEE_CHANGE_TOLERANCE_PERCENT is not a stingified integer" do
    :ok = System.put_env(@env_fee_adapter, "feed")

    :ok = System.put_env(@env_fee_change_tolerance_percent, "1.5")
    assert_raise RuntimeError, "Invalid integer: 1.5", fn -> SetFeeFeedAdapterOpts.load([], []) end

    :ok = System.put_env(@env_fee_change_tolerance_percent, "not integer")
    assert_raise RuntimeError, "Invalid integer: not integer", fn -> SetFeeFeedAdapterOpts.load([], []) end
  end

  test "raises an ArgumentError when STORED_FEE_UPDATE_INTERVAL_MINUTES is not a stingified integer" do
    :ok = System.put_env(@env_fee_adapter, "feed")
    :ok = System.put_env(@env_stored_fee_update_interval_minutes, "not a number")

    :ok = System.put_env(@env_stored_fee_update_interval_minutes, "100.20")
    assert_raise RuntimeError, "Invalid integer: 100.20", fn -> SetFeeFeedAdapterOpts.load([], []) end

    :ok = System.put_env(@env_stored_fee_update_interval_minutes, "not integer")
    assert_raise RuntimeError, "Invalid integer: not integer", fn -> SetFeeFeedAdapterOpts.load([], []) end
  end

  test "does not touch the configuration that's not present as env var" do
    adapter_opts = [
      fee_feed_url: "http://example.com/fee-feed-url-original",
      fee_change_tolerance_percent: 10,
      stored_fee_update_interval_minutes: 30
    ]

    config = [
      omg_child_chain: [fee_adapter: {OMG.ChildChain.Fees.FeedAdapter, opts: adapter_opts}]
    ]

    # Intentionally not configuring @env_fee_feed_url and @env_stored_fee_update_interval_minutes
    :ok = System.put_env(@env_fee_adapter, "feed")
    :ok = System.put_env(@env_fee_change_tolerance_percent, "50")
    config = SetFeeFeedAdapterOpts.load(config, [])

    {adapter, opts: new_opts} = config[:omg_child_chain][:fee_adapter]

    assert adapter == FeedAdapter
    assert new_opts[:fee_feed_url] == adapter_opts[:fee_feed_url]
    assert new_opts[:fee_change_tolerance_percent] == 50
    assert new_opts[:stored_fee_update_interval_minutes] == adapter_opts[:stored_fee_update_interval_minutes]
  end

  test "does not change the configuration when FEE_ADAPTER is not \"feed\"" do
    :ok = System.put_env(@env_fee_adapter, "not_feed_adapter")
    :ok = System.put_env(@env_fee_feed_url, "http://example.com/fee-feed-url")
    :ok = System.put_env(@env_fee_change_tolerance_percent, "10")
    :ok = System.put_env(@env_stored_fee_update_interval_minutes, "60000")

    assert SetFeeFeedAdapterOpts.load([], []) == []
  end

  test "no other configurations got affected" do
    :ok = System.put_env(@env_fee_adapter, "feed")
    :ok = System.put_env(@env_fee_feed_url, "http://example.com/fee-feed-url")
    :ok = System.put_env(@env_fee_change_tolerance_percent, "10")
    :ok = System.put_env(@env_stored_fee_update_interval_minutes, "60000")
    config = SetFeeFeedAdapterOpts.load([], [])

    assert Keyword.delete(config[@app], @config_key) == []
  end
end
