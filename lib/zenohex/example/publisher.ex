defmodule Zenohex.Example.Publisher do
  use GenServer

  def put(payload) do
    put(__MODULE__, payload)
  end

  def put(name, payload) do
    GenServer.call(name, {:put, payload})
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
end
