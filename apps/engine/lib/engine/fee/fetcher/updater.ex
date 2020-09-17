defmodule Engine.Fee.Fetcher.Updater do
  @moduledoc """
  Decides whether fees will be updated from the fetched fees from the feed.
  """

  alias Engine.Fee
  alias Engine.Fee.Fetcher.Updater.Merger

  @type can_update_result_t :: {:ok, Fee.full_fee_t()} | :no_changes

  # Internal data structure resulted from merge `stored_fees` and `fetched_fees` by tx type.
  # See `merge_specs_by_tx_type/2`
  @typep maybe_unpaired_fee_specs_merge_t :: %{non_neg_integer() => Fee.fee_t() | {Fee.fee_t(), Fee.fee_t()}}

  # As above but fully paired, which means `stored_fees` and `fetched_fees` support the same tx types
  @typep paired_fee_specs_merge_t :: %{non_neg_integer() => {Fee.fee_t(), Fee.fee_t()}}

  @doc """
  Newly fetched fees will be effective as long as the amount change on any token is significant
  or the time passed from previous update exceeds the update interval.
  """
  @spec can_update(
          stored_fees :: Fee.full_fee_t() | nil,
          fetched_fees :: Fee.full_fee_t(),
          tolerance_percent :: pos_integer()
        ) :: can_update_result_t()
  def can_update(fee_spec, fee_spec, _tolerance_percent), do: :no_changes

  def can_update(nil, new_fee_spec, _tolerance_percent), do: {:ok, new_fee_spec}

  def can_update(stored_fees, fetched_fees, tolerance_percent) do
    merged = merge_specs_by_tx_type(stored_fees, fetched_fees)

    with false <- stored_and_fetched_differs_on_tx_type?(merged),
         false <- stored_and_fetched_differs_on_token?(merged),
         amount_diffs = Map.values(Merger.merge_specs(stored_fees, fetched_fees)),
         false <- is_change_significant?(amount_diffs, tolerance_percent) do
      :no_changes
    else
      _ -> {:ok, fetched_fees}
    end
  end

  @spec merge_specs_by_tx_type(Fee.full_fee_t(), Fee.full_fee_t()) :: maybe_unpaired_fee_specs_merge_t()
  defp merge_specs_by_tx_type(stored_specs, fetched_specs) do
    Map.merge(stored_specs, fetched_specs, fn _t, stored_fees, fetched_fees -> {stored_fees, fetched_fees} end)
  end

  # Tells whether each tx_type in stored fees has a corresponding fees in fetched
  # Returns `true` when there is a mismatch
  @spec stored_and_fetched_differs_on_tx_type?(maybe_unpaired_fee_specs_merge_t()) :: boolean()
  defp stored_and_fetched_differs_on_tx_type?(merged_specs) do
    merged_specs
    |> Map.values()
    |> Enum.all?(&Kernel.is_tuple/1)
    |> Kernel.not()
  end

  # Checks whether previously stored and fetched fees differs on token
  # Returns `true` when there is a mismatch
  @spec stored_and_fetched_differs_on_token?(paired_fee_specs_merge_t()) :: boolean()
  defp stored_and_fetched_differs_on_token?(merged_specs) do
    Enum.any?(merged_specs, &merge_pair_differs_on_token?/1)
  end

  @spec merge_pair_differs_on_token?({non_neg_integer(), {Fee.fee_t(), Fee.fee_t()}}) :: boolean()
  defp merge_pair_differs_on_token?({_type, {stored_fees, fetched_fees}}) do
    not MapSet.equal?(
      stored_fees |> Map.keys() |> MapSet.new(),
      fetched_fees |> Map.keys() |> MapSet.new()
    )
  end

  # Change is significant when
  #  - token amount difference exceeds the tolerance level,
  #  - there is missing token in any of specs, so token support was either added or removed
  #    in the update.
  @spec is_change_significant?(list(Fee.merged_fee_t()), non_neg_integer()) :: boolean()
  defp is_change_significant?(token_amounts, tolerance_percent) do
    tolerance_rate = tolerance_percent / 100

    token_amounts
    |> Enum.flat_map(&Map.values/1)
    |> Enum.any?(&amount_diff_exceeds_tolerance?(&1, tolerance_rate))
  end

  defp amount_diff_exceeds_tolerance?([_no_change], _rate), do: false

  defp amount_diff_exceeds_tolerance?([stored, fetched], rate) do
    abs(stored - fetched) / stored >= rate
  end
end
