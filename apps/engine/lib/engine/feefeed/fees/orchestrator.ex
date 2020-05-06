defmodule Engine.Feefeed.Fees.Orchestrator do
  @moduledoc """
  This modules waits for cast that will trigger a fee update
  Every iteration
   - triggered from rules worker and/or every X minutes (configurable)
   - get last fee rules from DB
   - computes
   - store fees in DB if necessary
  """

  use GenServer

  alias Engine.Configuration
  alias Ecto.UUID
  alias Engine.DB.FeeRules
  alias Engine.DB.Fees
  alias Engine.Feefeed.Fees.Calculator

  require Logger
  @db_fetch_retry_interval Configuration.db_fetch_retry_interval()

  @doc """
  Starts the server with the given options.
  """
  @spec start_link(keyword()) :: {:ok, pid()}
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  @spec init(keyword()) :: {:ok, %{}}
  def init(_opts) do
    _ = Logger.info("Starting #{__MODULE__}")
    {:ok, %{}}
  end

  ## Client APIs
  ##

  @doc """
  Trigger compute_fees asynchronously.
  This function computes the fees based on the fee rules and store
  them in the database if needed.
  Always returns `:ok`.
  """
  @spec compute_fees(GenServer.server() | nil, UUID.t()) :: :ok
  def compute_fees(pid \\ __MODULE__, fee_rules_uuid) do
    GenServer.cast(pid, {:compute_fees, fee_rules_uuid})
  end

  ## Callbacks
  ##

  @impl true
  @spec handle_cast({:compute_fees, UUID.t()}, %{}) :: {:noreply, %{}}
  def handle_cast({:compute_fees, fee_rules_uuid}, state) do
    {:ok, %{data: fee_rules}} = fetch_latest_fee_rules_with_uuid(fee_rules_uuid, 0)
    {:ok, fees} = Calculator.calculate(fee_rules)

    _ =
      case should_update(fees) do
        {:noop, fees} ->
          Logger.info("Fees: #{inspect(fees)} already up-to-date, not updating")

        {:ok, fees} ->
          update_fees(fees, fee_rules_uuid)
      end

    {:noreply, state}
  end

  ## Priv
  ##
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

  defp fetch_latest_fee_rules_with_uuid(uuid, retry_count) do
    case {FeeRules.fetch_latest(), retry_count} do
      {{:ok, %{uuid: ^uuid}} = fee_rules, _} ->
        fee_rules

      {{:ok, fee_rules}, 3} ->
        {:error, :not_found, "The latest fee rule: #{inspect(fee_rules)} does not match the given uuid: #{uuid}"}

      {_, retry_count} ->
        _ =
          Logger.warn(
            "Warning: Fee rule with uuid: #{uuid} not found in DB, retrying in #{@db_fetch_retry_interval} ms. Current rety count: #{
              retry_count
            }"
          )

        Process.sleep(@db_fetch_retry_interval)
        fetch_latest_fee_rules_with_uuid(uuid, retry_count + 1)
    end
  end
end
