defmodule Zenohex.Examples.Subscriber.Impl do
  @moduledoc false

  use GenServer

  require Logger

  alias Zenohex.Session
  alias Zenohex.Subscriber

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    session = Map.fetch!(args, :session)
    key_expr = Map.fetch!(args, :key_expr)
    callback = Map.fetch!(args, :callback)

    {:ok, subscriber} = Session.declare_subscriber(session, key_expr)
    state = %{subscriber: subscriber, callback: callback}
    recv_timeout(state)

    {:ok, state}
  end

  def handle_info(:loop, state) do
    recv_timeout(state)

    {:noreply, state}
  end

  defp recv_timeout(state) do
    case Subscriber.recv_timeout(state.subscriber) do
      {:ok, sample} ->
        state.callback.(sample)
        send(self(), :loop)

      {:error, :timeout} ->
        send(self(), :loop)

      {:error, error} ->
        Logger.error(inspect(error))
    end
  end
end
