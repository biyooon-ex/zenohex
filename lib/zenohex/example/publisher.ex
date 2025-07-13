defmodule Zenohex.Example.Publisher do
  @moduledoc false

  use GenServer

  def put(payload) do
    put(__MODULE__, payload)
  end

  def put(name, payload) do
    GenServer.call(name, {:put, payload})
  end

  def delete() do
    delete(__MODULE__)
  end

  def delete(name) do
    GenServer.call(name, :delete)
  end

  def start_link(args) do
    name = Keyword.get(args, :name, __MODULE__)
    GenServer.start_link(__MODULE__, args, name: name)
  end

  def init(args) do
    session_id =
      Keyword.get(args, :session_id) ||
        Zenohex.Session.open() |> then(fn {:ok, session_id} -> session_id end)

    key_expr = Keyword.get(args, :key_expr, "key/expr")

    {:ok, publisher_id} = Zenohex.Session.declare_publisher(session_id, key_expr)

    {:ok,
     %{
       publisher_id: publisher_id
     }}
  end

  def handle_call({:put, payload}, _from, state) do
    %{publisher_id: publisher_id} = state
    reply = Zenohex.Publisher.put(publisher_id, payload)
    {:reply, reply, state}
  end

  def handle_call(:delete, _from, state) do
    %{publisher_id: publisher_id} = state
    reply = Zenohex.Publisher.delete(publisher_id)
    {:reply, reply, state}
  end
end
