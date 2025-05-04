defmodule ZenohexTest do
  use ExUnit.Case

  test "pub/sub" do
    {:ok, session_id} = Zenohex.Session.open()
    {:ok, publisher_id} = Zenohex.Session.declare_publisher(session_id, "key/expr")
    {:ok, _subscriber_id} = Zenohex.Session.declare_subscriber(session_id, "key/expr", self())

    :ok = Zenohex.Publisher.put(publisher_id, "Hello Zenoh Dragon")

    assert_receive %Zenohex.Sample{
      key_expr: "key/expr",
      payload: "Hello Zenoh Dragon",
      encoding: "zenoh/bytes"
    }
  end

  test "get/reply" do
    {:ok, session_id} = Zenohex.Session.open()
    {:ok, _queryable_id} = Zenohex.Session.declare_queryable(session_id, "key/expr", self())
    task = Task.async(Zenohex.Session, :get, [session_id, "key/expr", 100])

    assert_receive %Zenohex.Query{
                     key_expr: "key/expr",
                     parameters: "",
                     payload: nil,
                     encoding: nil,
                     zenoh_query: _zenoh_query
                   } = query

    :ok = Zenohex.Query.reply(%{query | key_expr: "key/expr", payload: "Hello Zenoh Dragon"})

    assert {:ok, %Zenohex.Sample{}} = Task.await(task)
  end
end
