defmodule Engine.Callback do
  @moduledoc """
  General abstraction for Event Callbacks. This provides behaviors and
  hooks like, storing the event height.
  """

  import Ecto.Query
  alias Engine.DB.ListenerState
  alias Engine.Ethereum.RootChain.Event

  @type events :: list(Event.t())
  @type listener :: atom()
  @type response :: {:ok, map()} | {:error, :atom, any(), any()}

  @callback callback(events(), listener()) :: response()

  @doc """
  Adds a multi to update our Listener state.
  """
  @spec update_listener_height(Ecto.Multi.t(), events(), listener()) :: Ecto.Multi.t()
  def update_listener_height(multi, events, listener) do
    height = find_tip_eth_height(events)
    changeset = ListenerState.update_height(listener, height)

    Ecto.Multi.run(multi, :update_listener_height, fn repo, _changes ->
      _ = repo.insert(changeset, 
        on_conflict: on_conflict(listener, height), 
        conflict_target: :listener,
        stale_error_field: :listener
      )

      # This is a hack to get around the `on_conflict` stale entry in the event
      # that a listener DOES exist AND is more up to date than our
      # given height. This acts as a `on_conflict: :nothing`, so to speak.
      {:ok, changeset}
    end)
  end

  defp find_tip_eth_height(events) do
    Enum.max_by(events, fn event -> event.eth_height end, fn -> 0 end).eth_height
  end

  # We run a query to see if the listener is stale compared to our height,
  # if so, we attempt to update with our height.
  defp on_conflict(listener, height) do
    query = ListenerState.stale_height(listener, height)
    update(query, set: [height: ^height])
  end
end
