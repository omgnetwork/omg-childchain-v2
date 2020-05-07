defmodule Engine.Feefeed.Rules.Worker do
  @moduledoc """
  Where the magic happens! This GenServer is linked with the
  Scheduler GenServer and will pull the fee rules using the Source
  GenServer every time the Scheduler ticks. It will then check if
  the rules have changed and store the new ones if that's the case.
  """

  use GenServer

  alias Engine.DB.FeeRules
  alias Engine.Feefeed.Rules.Parser
  alias Engine.Feefeed.Rules.Source
  alias Engine.Feefeed.Rules.Worker.Update
  require Logger
  @type t() :: %__MODULE__{config: Keyword.t()}
  defstruct [:config]

  @doc """
  Trigger update asynchronously. This function ensures the rules source has been updated
  at a remote location before storing the updated rules to the database. Always returns
  `:ok`.
  """
  @spec update(GenServer.server()) :: :ok
  def update(pid \\ __MODULE__) do
    GenServer.cast(pid, :update)
  end

  @doc """
  Starts the server with the given options.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, Keyword.get(opts, :name, __MODULE__))
  end

  @impl true
  @spec init(name: atom(), config: Source.source_config()) :: {:ok, t()}
  def init(opts) do
    config = Keyword.fetch!(opts, :config)
    _ = Logger.info("Starting #{__MODULE__}")

    {:ok, %__MODULE__{config: config}}
  end

  ## Callbacks
  ##
  @impl true
  @spec handle_cast(:update, t()) :: {:noreply, t()}
  def handle_cast(:update, state) do
    {:ok, body} = Source.fetch(state.config)
    {:ok, rules} = Parser.decode_and_validate(body)

    _ =
      case should_update(rules) do
        {:noop, _} ->
          Logger.info("Rules already up-to-date, not updating...")

        {:ok, rules} ->
          {:ok, %{uuid: fee_rules_uuid}} = update_rules(rules)
          Update.fees(fee_rules_uuid, rules)
      end

    {:noreply, state}
  end

  defp should_update(rules) do
    case FeeRules.fetch_latest() do
      {:ok, %{data: ^rules}} ->
        {:noop, rules}

      _ ->
        {:ok, rules}
    end
  end

  defp update_rules(rules) do
    {:ok, rules} = FeeRules.insert_rules(rules)
    _ = Logger.info("Fee rules updated #{inspect(rules.uuid)}")

    {:ok, rules}
  end
end
