defmodule Engine.Fees.FeedAdapter do
  @moduledoc """
  Adapter pulls actual fees prices from fee feed.
  """
  @behaviour Engine.Fees.Adapter

  alias Engine.Fees.FeeUpdater
  alias Engine.Fees.Client

  @doc """
  Pulls the fee specification from fees feed. Feed updates fee prices based on Ethereum's gas price.
  """
  @impl true
  def get_fee_specs(opts, actual_fee_specs, updated_at) do
    fee_feed_url = Keyword.fetch!(opts, :fee_feed_url)

    with {:ok, fee_specs_from_feed} <- Client.all_fees(fee_feed_url),
         {:ok, {new_updated_at, new_fee_specs}} <-
           can_update(opts, actual_fee_specs, fee_specs_from_feed, updated_at) do
      {:ok, new_fee_specs, new_updated_at}
    else
      :no_changes -> :ok
      error -> error
    end
  end

  defp can_update(opts, stored_specs, fetched_specs, updated_at) do
    tolerance_percent = Keyword.fetch!(opts, :fee_change_tolerance_percent)
    update_interval_minutes = Keyword.fetch!(opts, :stored_fee_update_interval_minutes)

    FeeUpdater.can_update(
      {updated_at, stored_specs},
      {:os.system_time(:second), fetched_specs},
      tolerance_percent,
      update_interval_minutes * 60
    )
  end
end
