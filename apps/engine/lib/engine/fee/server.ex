defmodule Engine.Fee.Server do
  @moduledoc """
  Maintains current fee rates and tokens in which fees may be paid.

  Periodically updates fees information from an external source.

  Fee's file parsing and rules of transaction's fee validation are in `OMG.Fee`
  """
  use GenServer

  alias Ecto.Multi
  alias Engine.DB.Fee, as: FeeDB
  alias Engine.Fee
  alias Engine.Fee.Fetcher
  alias Engine.Fee.Fetcher.Updater.Merger
  alias Engine.Repo
  alias Status.Alert.Alarm

  require Logger

  defstruct [
    :fee_fetcher_check_interval_ms,
    :fee_buffer_duration_ms,
    :fee_fetcher_opts,
    fee_fetcher_check_timer: nil,
    expire_fee_timer: nil,
    fee_update_error: false
  ]

  @typep t() :: %__MODULE__{
           fee_fetcher_check_interval_ms: pos_integer(),
           fee_buffer_duration_ms: pos_integer(),
           fee_fetcher_opts: Keyword.t(),
           fee_fetcher_check_timer: :timer.tref(),
           expire_fee_timer: :timer.tref(),
           fee_update_error: boolean()
         }

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(args) do
    state = Kernel.struct(__MODULE__, args)

    interval = state.fee_fetcher_check_interval_ms
    {:ok, fee_fetcher_check_timer} = :timer.send_interval(interval, self(), :update_fee_specs)
    new_state = %__MODULE__{state | fee_fetcher_check_timer: fee_fetcher_check_timer}

    _ = Logger.info("Started #{inspect(__MODULE__)}")

    _ = update_fee_specs(state)

    {:ok, new_state}
  end

  @doc """
  Returns a list of amounts that are accepted as a fee for each token/type.
  These amounts include the currently supported fees plus the buffered ones.
  """
  @spec accepted_fees() :: {:ok, Fee.typed_merged_fee_t()} | {:error, :fee_update_error}
  def accepted_fees() do
    case fee_server_healthy?() do
      true ->
        fees = load_accepted_fees()
        {:ok, fees.term}

      false ->
        {:error, :fee_update_error}
    end
  end

  @doc """
  Returns currently accepted tokens and amounts in which transaction fees are collected for each transaction type
  """
  @spec current_fees() :: {:ok, Fee.full_fee_t()} | {:error, :fee_update_error}
  def current_fees() do
    case fee_server_healthy?() do
      true ->
        fees = load_current_fees()
        {:ok, fees.term}

      false ->
        {:error, :fee_update_error}
    end
  end

  def handle_call(:healthy?, _from, state) do
    {:reply, not state.fee_update_error, state}
  end

  # The way this works (in a multi childchain setup) is that insert/1 has on_conflict: nothing.
  # Which has a conflict on the `hash` and `type` columns on fees. If multiple childchains would
  # try to insert fees at the same time any subsequent insertion would be ignored.
  # remove_previous_fees is a delete and we're ignoring "successful" results
  def handle_info(:expire_previous_fees, state) do
    current_fees = load_current_fees()
    previous_fees = load_previous_fees()

    if fees_expired?(previous_fees, current_fees, state.fee_buffer_duration_ms) do
      merged_fee_specs = Merger.merge_specs(current_fees.term, nil)

      Repo.transaction(fn ->
        {:ok, _} = FeeDB.insert(%{term: merged_fee_specs, type: :merged_fees})
        {_, _} = FeeDB.remove_previous_fees()
      end)
    end

    _ = Logger.info("Previous fees are now invalid and current fees must be paid")
    {:noreply, state}
  rescue
    error ->
      _ = Logger.error("Exception during fees expire. Reason: #{inspect(error)}")
      {:noreply, %{state | fee_update_error: true}}
  end

  def handle_info(:update_fee_specs, state) do
    new_state =
      case update_fee_specs(state) do
        {:ok, updated_state} ->
          Alarm.clear(invalid_fee_source())
          %{updated_state | fee_update_error: false}

        :ok ->
          Alarm.clear(invalid_fee_source())
          %{state | fee_update_error: false}

        _ ->
          Alarm.set(invalid_fee_source())
          %{state | fee_update_error: true}
      end

    {:noreply, new_state}
  end

  @spec invalid_fee_source() :: {:invalid_fee_source, %{:node => atom(), :reporter => Engine.Fee.Server}}
  defp invalid_fee_source() do
    {:invalid_fee_source, %{node: Node.self(), reporter: __MODULE__}}
  end

  @spec update_fee_specs(t()) :: :ok | {:ok, map()} | {:error, {atom(), any()}}
  defp update_fee_specs(state) do
    current_fee_specs = load_current_fees()

    case Fetcher.get_fee_specs(state.fee_fetcher_opts, current_fee_specs && current_fee_specs.term) do
      {:ok, fee_specs} ->
        :ok = save_fees(fee_specs)
        _ = Logger.info("Reloaded fee specs from FeeFetcher")

        new_expire_fee_timer = start_expiration_timer(state.expire_fee_timer, state.fee_buffer_duration_ms)
        {:ok, %__MODULE__{state | expire_fee_timer: new_expire_fee_timer}}

      :ok ->
        :ok

      error ->
        _ = Logger.error("Unable to update fees. Reason: #{inspect(error)}")

        error
    end
  rescue
    error ->
      _ = Logger.error("Exception during fees update. Reason: #{inspect(error)}")
      error
  end

  defp fees_expired?(nil, _current_fees, _fee_buffer_duration_ms), do: false

  defp fees_expired?(_previous_fees, nil, _fee_buffer_duration_ms), do: false

  defp fees_expired?(previous_fees, current_fees, fee_buffer_duration_ms) do
    duration = DateTime.diff(current_fees.inserted_at, previous_fees.inserted_at, :microsecond)

    duration > fee_buffer_duration_ms
  end

  defp start_expiration_timer(timer, fee_buffer_duration_ms) do
    # If a timer was already started, we cancel it
    _ = if timer != nil, do: Process.cancel_timer(timer)
    # We then start a new timer that will set the previous fees to nil uppon expiration
    Process.send_after(self(), :expire_previous_fees, fee_buffer_duration_ms)
  end

  defp save_fees(new_fee_specs) do
    {:ok, _} =
      Multi.new()
      |> Multi.run(:insert_current_fees, fn _repo, _changes ->
        FeeDB.insert(%{term: new_fee_specs, type: :current_fees})
      end)
      |> Multi.run(:update_merged_fees, fn _repo, _changes ->
        :ok = update_merged_fees(new_fee_specs)

        {:ok, nil}
      end)
      |> Repo.transaction()

    :ok
  end

  defp update_merged_fees(new_fee_specs) do
    # we will update merged fees only if previous merged fees are expired, i.e.
    # previous_fees are deleted
    _ =
      if is_nil(load_previous_fees()) do
        previous_fee_specs = load_current_fees()
        merged_fee_specs = Merger.merge_specs(new_fee_specs, previous_fee_specs && previous_fee_specs.term)
        {:ok, _} = FeeDB.insert(%{term: previous_fee_specs && previous_fee_specs.term, type: :previous_fees})
        {:ok, _} = FeeDB.insert(%{term: merged_fee_specs, type: :merged_fees})
      end

    :ok
  end

  defp load_current_fees() do
    case FeeDB.fetch_current_fees() do
      {:ok, fees} -> fees
      _ -> nil
    end
  end

  defp load_accepted_fees() do
    case FeeDB.fetch_merged_fees() do
      {:ok, fees} -> fees
      _ -> nil
    end
  end

  defp load_previous_fees() do
    case FeeDB.fetch_previous_fees() do
      {:ok, fees} -> fees
      _ -> nil
    end
  end

  defp fee_server_healthy?() do
    GenServer.call(__MODULE__, :healthy?)
  end
end
