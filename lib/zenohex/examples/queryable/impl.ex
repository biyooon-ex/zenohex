defmodule Zenohex.Examples.Queryable.Impl do
  @moduledoc false

  use GenServer

  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    session = Map.fetch!(args, :session)
    key_expr = Map.fetch!(args, :key_expr)
    callback = Map.fetch!(args, :callback)

    {:ok, queryable} = Zenohex.Session.declare_queryable(session, key_expr)
    state = %{queryable: queryable, callback: callback}

    recv_timeout(state)

    {:ok, state}
  end

  def handle_info(:loop, state) do
    recv_timeout(state)

    {:noreply, state}
  end

  def recv_timeout(state) do
    case Zenohex.Queryable.recv_timeout(state.queryable) do
      {:ok, query} ->
        state.callback.(query)
        send(self(), :loop)

      {:error, :timeout} ->
        send(self(), :loop)

      {:error, error} ->
        Logger.error(inspect(error))
    end
  end
end
