defmodule Engine.Fees.FeeServer do
  @moduledoc """
  Maintains current fee rates and tokens in which fees may be paid.

  Periodically updates fees information from an external source (defined in config
  by fee_adapter).

  Fee's file parsing and rules of transaction's fee validation are in `OMG.Fees`
  """
  use GenServer

  alias Engine.Fees.FeeMerger
  alias Engine.Fees.Fees
  alias Status.Alert.Alarm

  require Logger

  defstruct [
    :fee_adapter_check_interval_ms,
    :fee_buffer_duration_ms,
    :fee_adapter,
    :fee_adapter_opts,
    fee_adapter_check_timer: nil,
    expire_fee_timer: nil
  ]

  @typep t() :: %__MODULE__{
           fee_adapter_check_interval_ms: pos_integer(),
           fee_buffer_duration_ms: pos_integer(),
           fee_adapter: Engine.Fees.FeedAdapter,
           fee_adapter_opts: Keyword.t(),
           fee_adapter_check_timer: :timer.tref(),
           expire_fee_timer: :timer.tref()
         }

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(args) do
    :ok = ensure_ets_init()

    {:ok, state} =
      __MODULE__
      |> Kernel.struct(args)
      |> update_fee_specs()

    interval = state.fee_adapter_check_interval_ms
    {:ok, fee_adapter_check_timer} = :timer.send_interval(interval, self(), :update_fee_specs)
    state = %__MODULE__{state | fee_adapter_check_timer: fee_adapter_check_timer}

    _ = Logger.info("Started #{inspect(__MODULE__)}")

    {:ok, state}
  end

  @doc """
  Returns a list of amounts that are accepted as a fee for each token/type.
  These amounts include the currently supported fees plus the buffered ones.
  """
  @spec accepted_fees() :: {:ok, Fees.typed_merged_fee_t()}
  def accepted_fees() do
    {:ok, load_accepted_fees()}
  end

  @doc """
  Returns currently accepted tokens and amounts in which transaction fees are collected for each transaction type
  """
  @spec current_fees() :: {:ok, Fees.full_fee_t()}
  def current_fees() do
    {:ok, load_current_fees()}
  end

  def handle_info(:expire_previous_fees, state) do
    merged_fee_specs =
      :fees_bucket
      |> :ets.lookup_element(:fees, 2)
      |> FeeMerger.merge_specs(nil)

    true =
      :ets.insert(:fees_bucket, [
        {:previous_fees, nil},
        {:merged_fees, merged_fee_specs}
      ])

    _ = Logger.info("Previous fees are now invalid and current fees must be paid")
    {:noreply, state}
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

  @spec invalid_fee_source() :: {:invalid_fee_source, map()}
  defp invalid_fee_source(),
    do: {:invalid_fee_source, %{node: Node.self(), reporter: __MODULE__}}

  @spec update_fee_specs(t()) :: :ok | {:ok, t()} | {:error, list({:error, atom(), any(), non_neg_integer() | nil})}
  defp update_fee_specs(
         %__MODULE__{
           fee_adapter: fee_adapter,
           fee_adapter_opts: fee_adapter_opts,
           expire_fee_timer: current_expire_fee_timer,
           fee_buffer_duration_ms: fee_buffer_duration_ms
         } = state
       ) do
    source_updated_at = :ets.lookup_element(:fees_bucket, :fee_specs_source_updated_at, 2)
    current_fee_specs = load_current_fees()

    case fee_adapter.get_fee_specs(fee_adapter_opts, current_fee_specs, source_updated_at) do
      {:ok, fee_specs, source_updated_at} ->
        :ok = save_fees(fee_specs, source_updated_at)
        _ = Logger.info("Reloaded fee specs from #{inspect(fee_adapter)}, changed at #{inspect(source_updated_at)}")
        new_expire_fee_timer = start_expiration_timer(current_expire_fee_timer, fee_buffer_duration_ms)

        _ =
          Logger.info(
            "Timer started: previous fees will still be valid for #{inspect(fee_buffer_duration_ms)} ms, or until new fees are set"
          )

        {:ok, %__MODULE__{state | expire_fee_timer: new_expire_fee_timer}}

      :ok ->
        :ok

      error ->
        _ = Logger.error("Unable to update fees from file. Reason: #{inspect(error)}")
        error
    end
  end

  defp save_fees(new_fee_specs, last_updated_at) do
    previous_fees_specs = :ets.lookup_element(:fees_bucket, :fees, 2)
    merged_fee_specs = FeeMerger.merge_specs(new_fee_specs, previous_fees_specs)

    true =
      :ets.insert(:fees_bucket, [
        {:updated_at, :os.system_time(:second)},
        {:fee_specs_source_updated_at, last_updated_at},
        {:fees, new_fee_specs},
        {:previous_fees, previous_fees_specs},
        {:merged_fees, merged_fee_specs}
      ])

    :ok
  end

  defp start_expiration_timer(timer, fee_buffer_duration_ms) do
    # If a timer was already started, we cancel it
    _ = if timer != nil, do: Process.cancel_timer(timer)
    # We then start a new timer that will set the previous fees to nil uppon expiration
    Process.send_after(self(), :expire_previous_fees, fee_buffer_duration_ms)
  end

  defp load_current_fees() do
    :ets.lookup_element(:fees_bucket, :fees, 2)
  end

  defp load_accepted_fees() do
    :ets.lookup_element(:fees_bucket, :merged_fees, 2)
  end

  defp ensure_ets_init() do
    _ = if :undefined == :ets.info(:fees_bucket), do: :ets.new(:fees_bucket, [:set, :protected, :named_table])

    true =
      :ets.insert(:fees_bucket, [
        {:fee_specs_source_updated_at, 0},
        {:fees, nil},
        {:previous_fees, nil},
        {:merged_fees, nil}
      ])

    :ok
  end
end
