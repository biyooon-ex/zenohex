defmodule Zenohex.Examples.PullSubscriber.Impl do
  @moduledoc false

  use GenServer

  require Logger

  alias Zenohex.Session
  alias Zenohex.PullSubscriber

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def pull() do
    GenServer.call(__MODULE__, :pull)
  end

  def init(args) do
    session = Map.fetch!(args, :session)
    key_expr = Map.fetch!(args, :key_expr)
    callback = Map.fetch!(args, :callback)

    {:ok, pull_subscriber} = Session.declare_pull_subscriber(session, key_expr)
    state = %{pull_subscriber: pull_subscriber, callback: callback}

    send(self(), :loop)

    {:ok, state}
  end

  def handle_info(:loop, state) do
    case PullSubscriber.recv_timeout(state.pull_subscriber) do
      {:ok, sample} ->
        state.callback.(sample)
        send(self(), :loop)

      {:error, :timeout} ->
        send(self(), :loop)

      {:error, error} ->
        Logger.error(inspect(error))
    end

    {:noreply, state}
  end

  def handle_call(:pull, _from, state) do
    :ok = PullSubscriber.pull(state.pull_subscriber)
    {:reply, :ok, state}
  end
end
