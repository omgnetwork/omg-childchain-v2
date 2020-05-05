defmodule Engine.Fees.Server do
  @moduledoc """
  Maintains current fee rates and tokens in which fees may be paid.

  Periodically updates fees information from an external source (defined in config
  by fee_adapter).

  Fee's file parsing and rules of transaction's fee validation are in `OMG.Fees`
  """
  use GenServer

  alias Engine.Fees
  alias Engine.Fees.Parser
  alias Engine.Fees.Server.Storage
  alias Status.Alert.Alarm

  require Logger

  @doc """
  Returns a list of amounts that are accepted as a fee for each token/type.
  These amounts include the currently supported fees plus the buffered ones.
  """
  @spec accepted_fees() :: {:ok, Fees.typed_merged_fee_t()}
  def accepted_fees() do
    {:ok, Storage.accepted_fees()}
  end

  @doc """
  Returns currently accepted tokens and amounts in which transaction fees are collected for each transaction type
  """
  @spec current_fees() :: {:ok, Fees.full_fee_t()}
  def current_fees() do
    {:ok, Storage.current_fees()}
  end

  defstruct [
    :fee_adapter_check_interval_ms,
    :fee_buffer_duration_ms,
    :fee_adapter,
    :fee_adapter_opts,
    :fee_adapter_check_timer,
    :expire_fee_timer,
    :ets
  ]

  @type t() :: %__MODULE__{
          fee_adapter_check_interval_ms: pos_integer(),
          fee_buffer_duration_ms: pos_integer(),
          fee_adapter: Engine.Fees.FileAdapter | Engine.Fees.FeedAdapter,
          fee_adapter_opts: Keyword.t(),
          fee_adapter_check_timer: :timer.tref(),
          expire_fee_timer: :timer.tref(),
          ets: atom()
        }

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  def init(opts) do
    _ = Logger.info("Started #{inspect(__MODULE__)}")
    ets = Storage.ensure_ets_init(Keyword.get(opts, :ets, :fees_bucket))

    {:ok, state, source_updated_at} =
      __MODULE__
      |> struct(Keyword.merge(opts, ets: ets))
      |> Storage.update_fee_specs()

    reloaded(state.fee_adapter, source_updated_at)

    interval = state.fee_adapter_check_interval_ms
    {:ok, fee_adapter_check_timer} = :timer.send_interval(interval, self(), :update_fee_specs)
    _ = Logger.info("Started #{inspect(__MODULE__)}")

    {:ok, %__MODULE__{state | fee_adapter_check_timer: fee_adapter_check_timer}}
  end

  def handle_info(:expire_previous_fees, state) do
    fees = Storage.current_fees(state)

    true =
      fees
      |> Parser.merge_specs(nil)
      |> Storage.expire_previous_fees(state)

    _ = Logger.info("Previous fees are now invalid and current fees must be paid")
    {:noreply, state}
  end

  def handle_info(:update_fee_specs, state) do
    new_state =
      case Storage.update_fee_specs(state) do
        {:ok, source_updated_at} ->
          reloaded(state.fee_adapter, source_updated_at)

          new_expire_fee_timer = start_expiration_timer(state.current_expire_fee_timer, state.fee_buffer_duration_ms)

          Alarm.clear(Alarm.Types.invalid_fee_source(__MODULE__))
          %{state | expire_fee_timer: new_expire_fee_timer}

        :ok ->
          Alarm.clear(Alarm.Types.invalid_fee_source(__MODULE__))
          state

        _ ->
          Alarm.set(Alarm.Types.invalid_fee_source(__MODULE__))
          state
      end

    {:noreply, new_state}
  end

  defp start_expiration_timer(timer, fee_buffer_duration_ms) do
    # If a timer was already started, we cancel it
    _ = if timer != nil, do: Process.cancel_timer(timer)
    # We then start a new timer that will set the previous fees to nil uppon expiration
    Process.send_after(self(), :expire_previous_fees, fee_buffer_duration_ms)
  end

  defp reloaded(fee_adapter, source_updated_at) do
    Logger.info("Reloaded fee specs from #{inspect(fee_adapter)}, changed at #{inspect(source_updated_at)}")
  end
end
