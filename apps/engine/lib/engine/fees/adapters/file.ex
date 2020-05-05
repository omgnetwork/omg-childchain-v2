defmodule Engine.Fees.Adapters.File do
  @moduledoc """
  Adapter for fees stored in a JSON file (defined in omg_child_chain/priv config :omg_child_chain,
  fee_adapter_opts: `specs_file_path` keyword opts).
  """
  @behaviour Engine.Fees.Adapter
  alias Engine.Fees.Adapters.Parser.Json

  require Logger

  @doc """
  Reads fee specification file if needed and returns its content.
  When using this adapter, the operator can change the fees by updating a
  JSON file that is loaded from disk (path variable).
  """

  @impl true
  def get_fee_specs(opts, _actual_fee_specs, recorded_file_updated_at) do
    path = get_path(opts)

    with {:changed, file_updated_at} <- check_file_changes(path, recorded_file_updated_at),
         {:ok, content} <- File.read(path),
         {:ok, fee_specs} <- Json.parse(content) do
      {:ok, fee_specs, file_updated_at}
    else
      {:unchanged, _last_changed_at} ->
        :ok

      error ->
        error
    end
  end

  defp check_file_changes(path, recorded_file_updated_at) do
    actual_file_updated_at = get_file_last_modified_timestamp(path)

    case actual_file_updated_at > recorded_file_updated_at do
      true ->
        {:changed, actual_file_updated_at}

      false ->
        {:unchanged, recorded_file_updated_at}
    end
  end

  defp get_file_last_modified_timestamp(path) do
    case File.stat(path, time: :posix) do
      {:ok, %File.Stat{mtime: mtime}} ->
        mtime

      # possibly wrong path - returns current timestamp to force file reload where file errors are handled
      _ ->
        :os.system_time(:second)
    end
  end

  # Get the specs file path from the provided opts. If not configured, it defaults back to
  # the child_chain source code's priv/fee_specs.json.
  #
  # Beware that we check with `is_binary/1` because a nil path should also use the default.
  defp get_path(opts) do
    case Keyword.fetch(opts, :specs_file_path) do
      {:ok, path} when is_binary(path) -> path
      _ -> Path.join(:code.priv_dir(:engine), "fee_specs.json")
    end
  end
end
