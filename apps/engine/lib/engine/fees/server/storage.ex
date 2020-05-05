defmodule Engine.Fees.Server.Storage do
  @moduledoc """
  Storage operations for Fees.
  """
  alias Engine.Fees.Parser
  alias Engine.Fees.Server

  require Logger

  @spec current_fees(Server.t()) :: term()
  def current_fees(state) do
    :ets.lookup_element(state.ets, :fees, 2)
  end

  def accepted_fees(ets) do
    :ets.lookup_element(ets, :merged_fees, 2)
  end

  def ensure_ets_init(name) do
    _ = if :undefined == :ets.info(name), do: :ets.new(name, [:set, :protected, :named_table])

    true =
      :ets.insert(name, [
        {:fee_specs_source_updated_at, 0},
        {:fees, nil},
        {:previous_fees, nil},
        {:merged_fees, nil}
      ])

    :ok
  end

  @spec expire_previous_fees(term(), Server.t()) :: true
  def expire_previous_fees(merged_fee_specs, state) do
    :ets.insert([{:previous_fees, nil}, {:merged_fees, merged_fee_specs}], state.ets)
  end

  def save_fees(ets, new_fee_specs, last_updated_at) do
    previous_fees_specs = :ets.lookup_element(ets, :fees, 2)
    merged_fee_specs = Parser.merge_specs(new_fee_specs, previous_fees_specs)

    true =
      :ets.insert(ets, [
        {:updated_at, :os.system_time(:second)},
        {:fee_specs_source_updated_at, last_updated_at},
        {:fees, new_fee_specs},
        {:previous_fees, previous_fees_specs},
        {:merged_fees, merged_fee_specs}
      ])

    :ok
  end

  @spec update_fee_specs(Server.t()) ::
          :ok | {:ok, Server.t()} | {:error, list({:error, atom(), any(), non_neg_integer() | nil})}
  def update_fee_specs(state) do
    source_updated_at = :ets.lookup_element(state.ets, :fee_specs_source_updated_at, 2)
    current_fee_specs = current_fees(state)

    case state.fee_adapter.get_fee_specs(state.fee_adapter_opts, current_fee_specs, source_updated_at) do
      {:ok, fee_specs, source_updated_at} ->
        :ok = save_fees(state.ets, fee_specs, source_updated_at)

        _ =
          Logger.info(
            "Timer started: previous fees will still be valid for #{inspect(state.fee_buffer_duration_ms)} ms, or until new fees are set"
          )

        {:ok, source_updated_at}

      :ok ->
        :ok

      error ->
        _ = Logger.error("Unable to update fees from file. Reason: #{inspect(error)}")
        error
    end
  end
end
