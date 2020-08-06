defmodule Engine.Fees.FeeFetcher do
  @moduledoc """
  Adapter pulls actual fees prices from fee feed.
  """

  alias Engine.Fees.FeeFetcher.Client
  alias Engine.Fees.FeeFetcher.FeeUpdater

  @doc """
  Pulls the fee specification from fees feed. Feed updates fee prices based on Ethereum's gas price.
  """
  @spec get_fee_specs(Keyword.t(), Engine.Fees.full_fee_t()) ::
          :ok
          | {:error, {:malformed_response, any()} | {:server_error, any()} | {:unsuccessful_response, any()}}
          | {:ok, Engine.Fees.full_fee_t()}
  def get_fee_specs(opts, actual_fee_specs) do
    fee_feed_url = Keyword.fetch!(opts, :fee_feed_url)

    with {:ok, fee_specs_from_feed} <- Client.all_fees(fee_feed_url),
         {:ok, new_fee_specs} <-
           can_update(opts, actual_fee_specs, fee_specs_from_feed) do
      {:ok, new_fee_specs}
    else
      :no_changes -> :ok
      error -> error
    end
  end

  defp can_update(opts, stored_specs, fetched_specs) do
    tolerance_percent = Keyword.fetch!(opts, :fee_change_tolerance_percent)

    FeeUpdater.can_update(
      stored_specs,
      fetched_specs,
      tolerance_percent
    )
  end
end
