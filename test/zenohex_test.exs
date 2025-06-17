defmodule ZenohexTest do
  use ExUnit.Case

  setup do
    {:ok, session_id} = Zenohex.Session.open()

    on_exit(fn -> :ok = Zenohex.Session.close(session_id) end)

    %{session_id: session_id}
  end

  test "pub/sub", %{session_id: session_id} do
    {:ok, publisher_id} = Zenohex.Session.declare_publisher(session_id, "key/expr")
    {:ok, _subscriber_id} = Zenohex.Session.declare_subscriber(session_id, "key/expr", self())

    :ok = Zenohex.Publisher.put(publisher_id, "Hello Zenoh Dragon")

    assert_receive %Zenohex.Sample{
      key_expr: "key/expr",
      payload: "Hello Zenoh Dragon",
      encoding: "zenoh/bytes"
    }
  end

  test "get/reply", %{session_id: session_id} do
    {:ok, _queryable_id} = Zenohex.Session.declare_queryable(session_id, "key/expr", self())

    task = Task.async(Zenohex.Session, :get, [session_id, "key/expr", 100])

    assert_receive %Zenohex.Query{
                     key_expr: "key/expr",
                     parameters: "",
                     payload: nil,
                     encoding: nil,
                     zenoh_query: _zenoh_query
                   } = query

    :ok = Zenohex.Query.reply(%{query | payload: "Hello Zenoh Dragon"})

    assert {:ok,
            %Zenohex.Sample{
              key_expr: "key/expr",
              payload: "Hello Zenoh Dragon",
              encoding: "zenoh/bytes"
            }} = Task.await(task)
  end
end
