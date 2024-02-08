defmodule Zenohex.Examples.QueryableServer do
  @moduledoc false

  use GenServer

  require Logger

  alias Zenohex.Session
  alias Zenohex.Queryable

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    session = Map.fetch!(args, :session)
    key_expr = Map.fetch!(args, :key_expr)
    callback = Map.fetch!(args, :callback)
    {:ok, queryable} = Session.declare_queryable(session, key_expr)

    send(self(), :loop)

    {:ok, %{queryable: queryable, callback: callback}}
  end

  def handle_info(:loop, state) do
    case Queryable.recv_timeout(state.queryable, 1000) do
      {:ok, query} ->
        state.callback.(query)
        send(self(), :loop)

      {:error, :timeout} ->
        send(self(), :loop)

      {:error, :disconnected} ->
        raise("unreachable!")

      {:error, error} ->
        Logger.error(inspect(error))
    end

    {:noreply, state}
  end
end
