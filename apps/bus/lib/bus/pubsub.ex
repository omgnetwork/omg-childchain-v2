defmodule Bus.PubSub do
  @moduledoc """
  Thin wrapper around the pubsub mechanism allowing us to not repeat ourselves when starting/broadcasting/subscribing

  All of the messages published will have `:internal_bus_event` prepended to the tuple to distinguish them


  """
  alias Phoenix.PubSub

  def child_spec(args \\ []) do
    args
    |> Keyword.put_new(:name, __MODULE__)
    |> PubSub.child_spec()
  end

  defmacro __using__(_) do
    quote do
      alias Bus.Event
      alias Phoenix.PubSub

      @doc """
      Fixes the name of the PubSub server and the variant of `Phoenix.PubSub` used
      """

      @doc """
      Subscribes the current process to the internal bus topic
      """
      def subscribe(topic, opts \\ [])

      def subscribe({origin, topic}, opts) when is_atom(origin) do
        PubSub.subscribe(Bus.PubSub, "#{origin}:#{topic}", opts)
      end

      def subscribe(topic, opts) do
        PubSub.subscribe(Bus.PubSub, topic, opts)
      end

      def local_broadcast(%Event{topic: topic, event: event, payload: payload}) do
        PubSub.local_broadcast(Bus.PubSub, topic, {:internal_event_bus, event, payload})
      end
    end
  end
end
