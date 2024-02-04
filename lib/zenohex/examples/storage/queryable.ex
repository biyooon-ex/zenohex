defmodule Zenohex.Examples.Storage.Queryable do
  use GenServer

  require Logger

  alias Zenohex.Session
  alias Zenohex.Queryable
  alias Zenohex.Examples.Storage.Store
  alias Zenohex.Query

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    {:ok, queryable} = Session.declare_queryable(args.session, args.key_expr)
    send(self(), :loop)
    {:ok, %{queryable: queryable}}
  end

  def handle_info(:loop, state) do
    case Queryable.recv_timeout(state.queryable, 1000) do
      {:ok, query} ->
        case store(query) do
          {:error, :not_found} ->
            nil

          {:ok, [sample]} ->
            :ok = Query.reply(query, sample)

            # NOTE: `send_redponse_final` is invoked When QueryInnter dropped.
            # So we need to do GC, which release ResourceArc<ExQueryRef>, to finish the reply.
            # ref. https://github.com/eclipse-zenoh/zenoh/blob/0.10.1-rc/zenoh/src/queryable.rs#L55-L69
            :erlang.garbage_collect()
        end

      {:error, :timeout} ->
        nil

      {:error, reason} ->
        Logger.error(inspect(reason))
    end

    send(self(), :loop)
    {:noreply, state}
  end

  defp store(query) when is_struct(query, Query) do
    Store.get(query.key_expr)
  end
end
