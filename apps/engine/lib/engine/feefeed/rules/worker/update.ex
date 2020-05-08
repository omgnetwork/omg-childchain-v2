defmodule Engine.Feefeed.Rules.Worker.Update do
  @moduledoc """
  Compute if fees need to be updated or not
  """
  alias Engine.DB.Fees
  alias Engine.Feefeed.Fees.Calculator

  require Logger

  def fees(fee_rules_uuid, fee_rules) do
    {:ok, fees} = Calculator.calculate(fee_rules)

    case should_update(fees) do
      {:noop, fees} ->
        Logger.info("Fees: #{inspect(fees)} already up-to-date, not updating")

      {:ok, fees} ->
        update_fees(fees, fee_rules_uuid)
    end
  end

  defp should_update(fees) do
    case Fees.fetch_latest() do
      {:ok, %{data: ^fees}} ->
        {:noop, fees}

      _ ->
        {:ok, fees}
    end
  end

  defp update_fees(fees, fee_rules_uuid) do
    {:ok, fees} = Fees.insert_fees(fees, fee_rules_uuid)
    _ = Logger.info("Fees updated #{inspect(fees.uuid)}")

    {:ok, fees}
  end
end
