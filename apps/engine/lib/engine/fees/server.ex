defmodule Engine.Fees.Server do
  @moduledoc """
  Maintains current fee rates and tokens in which fees may be paid.

  Periodically updates fees information from an external source.

  Fee's file parsing and rules of transaction's fee validation are in `OMG.Fees`
  """
  use GenServer

  alias Engine.DB.Fee, as: Fee
  alias Engine.Fees
  alias Engine.Fees.Fetcher
  alias Status.Alert.Alarm

  require Logger

  defstruct [
    :fee_fetcher_check_interval_ms,
    :fee_fetcher_opts,
    fee_fetcher_check_timer: nil
  ]

  @typep t() :: %__MODULE__{
           fee_fetcher_check_interval_ms: pos_integer(),
           fee_fetcher_opts: Keyword.t(),
           fee_fetcher_check_timer: :timer.tref()
         }

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(args) do
    {:ok, state} =
      __MODULE__
      |> Kernel.struct(args)
      |> update_fee_specs()

    interval = state.fee_fetcher_check_interval_ms
    {:ok, fee_fetcher_check_timer} = :timer.send_interval(interval, self(), :update_fee_specs)
    new_state = %__MODULE__{state | fee_fetcher_check_timer: fee_fetcher_check_timer}

    _ = Logger.info("Started #{inspect(__MODULE__)}")

    {:ok, new_state}
  end

  @doc """
  Returns currently accepted tokens and amounts in which transaction fees are collected for each transaction type
  """
  @spec current_fees() :: {:ok, Fees.full_fee_t()}
  def current_fees() do
    fees = load_current_fees()

    {:ok, fees.term}
  end

  def handle_info(:update_fee_specs, state) do
    new_state =
      case update_fee_specs(state) do
        {:ok, updated_state} ->
          Alarm.clear(invalid_fee_source())
          updated_state

        :ok ->
          Alarm.clear(invalid_fee_source())
          state

        _ ->
          Alarm.set(invalid_fee_source())
          state
      end

    {:noreply, new_state}
  end

  @spec invalid_fee_source() :: {:invalid_fee_source, %{:node => atom(), :reporter => Engine.Fees.Server}}
  defp invalid_fee_source() do
    {:invalid_fee_source, %{node: Node.self(), reporter: __MODULE__}}
  end

  @spec update_fee_specs(t()) :: :ok | {:ok, t()} | {:error, {atom(), any()}}
  defp update_fee_specs(state) do
    current_fee_specs = load_current_fees()

    case Fetcher.get_fee_specs(state.fee_fetcher_opts, current_fee_specs.term) do
      {:ok, fee_specs} ->
        {:ok, _} = save_fees(fee_specs)
        _ = Logger.info("Reloaded fee specs from FeeFetcher")

        {:ok, state}

      :ok ->
        :ok

      error ->
        _ = Logger.error("Unable to update fees. Reason: #{inspect(error)}")
        error
    end
  end

  defp save_fees(new_fee_specs) do
    Fee.insert(%{term: new_fee_specs, type: "current_fees"})
  end

  defp load_current_fees() do
    case Fee.fetch_latest() do
      {:ok, fees} -> fees
      _ -> nil
    end
  end
end
