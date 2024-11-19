defmodule Zenohex.Examples.Pong.Impl do
  @moduledoc false

  use GenServer

  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def start_pong_process() do
    GenServer.call(__MODULE__, :start_pong_process)
  end

  def init(args) do
    IO.inspect(args, label: "Pong.Impl args")
    IO.inspect("Opening Session…")

    session = Map.fetch!(args, :session)
    ping_key_expr = Map.fetch!(args, :ping_key_expr)
    pong_key_expr = Map.fetch!(args, :pong_key_expr)
    callback = Map.fetch!(args, :callback)

    {:ok, publisher} = Zenohex.Session.declare_publisher(session, pong_key_expr)
    {:ok, subscriber} = Zenohex.Session.declare_subscriber(session, ping_key_expr)

    state = %{publisher: publisher, subscriber: subscriber, callback: callback}
    {:ok, state}
  end

  def handle_call(:start_pong_process, _from, state) do
    send(self(), :start_pong_process)

    {:reply, :ok, state}
  end

  def handle_info(:start_pong_process, state) do
    IO.puts("Pong process started")

    recv_timeout(state)
    :ok = Zenohex.Publisher.put(state.publisher, "a")

    Process.sleep(100)
    send(self(), :start_pong_process)

    {:noreply, state}
  end

  def handle_info(:loop, state) do
    recv_timeout(state)
    {:noreply, state}
  end

  defp recv_timeout(state) do
    case Zenohex.Subscriber.recv_timeout(state.subscriber) do
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
