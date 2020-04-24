defmodule Bus.PubSub do
  @moduledoc """
  Thin wrapper around the pubsub mechanism allowing us to not repeat ourselves when starting/broadcasting/subscribing

  All of the messages published will have `:internal_bus_event` prepended to the tuple to distinguish them


  """
  alias Phoenix.PubSub

  def child_spec(args \\ []) do
    args
    |> Keyword.put_new(:name, __MODULE__)
    |> PubSub.PG2.child_spec()
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

      @doc """
      Broadcast a message with a prefix indicating that it is originating from the internal event bus

      Handle the message in the receiving process by e.g.
      ```
      def handle_info({:internal_bus_event, :some_event, my_payload}, state)
      ```
      """
      def broadcast(%Event{topic: topic, event: event, payload: payload}) when is_atom(event) do
        PubSub.broadcast(Bus.PubSub, topic, {:internal_event_bus, event, payload})
      end

      @doc """
      Same as `broadcast/1`, but performed on the local node
      """
      def direct_local_broadcast(%Event{topic: topic, event: event, payload: payload})
          when is_atom(event) do
        node_name = PubSub.node_name(Bus.PubSub)
        PubSub.direct_broadcast(node_name, Bus.PubSub, topic, {:internal_event_bus, event, payload})
      end
    end
  end
end
