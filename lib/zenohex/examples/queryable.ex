defmodule Zenohex.Examples.Queryable do
  @moduledoc false

  use GenServer

  require Logger

  def start_link(args) do
    name = Keyword.get(args, :name, __MODULE__)
    GenServer.start_link(__MODULE__, args, name: name)
  end

  def init(args) do
    session_id =
      Keyword.get(args, :session_id) ||
        Zenohex.Session.open() |> then(fn {:ok, session_id} -> session_id end)

    key_expr = Keyword.get(args, :key_expr, "key/expr")

    callback = Keyword.get(args, :callback, &Logger.debug("#{inspect(&1)}"))

    callback_payload = Keyword.get(args, :callback_payload, &inspect(&1))

    {:ok, queryable_id} = Zenohex.Session.declare_queryable(session_id, key_expr, self())

    {:ok,
     %{
       queryable_id: queryable_id,
       key_expr: key_expr,
       callback: callback,
       callback_payload: callback_payload
     }}
  end

  def handle_info(%Zenohex.Query{zenoh_query: zenoh_query} = query, state) do
    %{key_expr: key_expr, callback: callback, callback_payload: callback_payload} = state

    callback.(query)
    :ok = Zenohex.Query.reply(zenoh_query, key_expr, callback_payload.(query))

    {:noreply, state}
  end
end
