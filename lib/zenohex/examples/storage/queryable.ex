defmodule Zenohex.Examples.Storage.Queryable do
  @moduledoc false

  use GenServer

  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    {:ok, queryable} = Zenohex.Session.declare_queryable(args.session, args.key_expr)
    send(self(), :loop)
    {:ok, %{queryable: queryable}}
  end

  def handle_info(:loop, state) do
    case Zenohex.Queryable.recv_timeout(state.queryable) do
      {:ok, query} ->
        case store(query) do
          {:error, :not_found} ->
            nil

          {:ok, samples} ->
            Enum.each(samples, &Zenohex.Query.reply(query, &1))
            :ok = Zenohex.Query.finish_reply(query)
            # following line is not needed, this is just example of double call
            {:error, "ResponseFinal has already been sent"} = Zenohex.Query.finish_reply(query)
        end

      {:error, :timeout} ->
        nil

      {:error, reason} ->
        Logger.error(inspect(reason))
    end

    send(self(), :loop)
    {:noreply, state}
  end

  defp store(query) when is_struct(query, Zenohex.Query) do
    Zenohex.Examples.Storage.Store.get(query.key_expr)
  end
end
