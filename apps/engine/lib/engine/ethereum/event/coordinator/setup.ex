defmodule Engine.Ethereum.Event.Coordinator.Setup do
  @moduledoc """
   The setup of `Coordinator` for the child chain server - configures the relations between different
   event listeners
  """

  @doc """
  The `Coordinator` setup for the Childchain app. Summary of the configuration:

    - deposits are recognized after `finality_margin`
    - exit-related events don't have any finality margin, but wait for deposits
    - piggyback-related events must wait for IFE start events
  """

  def coordinator_setup(metrics_collection_interval, coordinator_eth_height_check_interval_ms, finality_margin) do
    {[
       metrics_collection_interval: metrics_collection_interval,
       coordinator_eth_height_check_interval_ms: coordinator_eth_height_check_interval_ms
     ],
     %{
       depositor: [finality_margin: deposit_finality_margin],
       exiter: [waits_for: :depositor, finality_margin: deposit_finality_margin],
       in_flight_exit: [waits_for: :depositor, finality_margin: deposit_finality_margin],
       piggyback: [waits_for: :in_flight_exit, finality_margin: deposit_finality_margin]
     }}
  end
end
