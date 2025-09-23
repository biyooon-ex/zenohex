defmodule Zenohex.QueryTest do
  use ExUnit.Case

  setup do
    {:ok, session_id} =
      Zenohex.Config.default()
      |> Zenohex.Test.Support.TestHelper.scouting_delay(0)
      |> Zenohex.Session.open()

    {:ok, queryable_id} = Zenohex.Session.declare_queryable(session_id, "key/expr", self())

    on_exit(fn ->
      Zenohex.Queryable.undeclare(queryable_id)
      Zenohex.Session.close(session_id)
    end)

    %{
      session_id: session_id,
      queryable_id: queryable_id
    }
  end

  test "reply/3", context do
    task =
      Task.async(Zenohex.Session, :get, [
        context.session_id,
        "key/expr/**",
        100
      ])

    assert_receive %Zenohex.Query{zenoh_query: zenoh_query}

    assert :ok = Zenohex.Query.reply(zenoh_query, "key/expr/1", "payload")

    assert {:ok, [%Zenohex.Sample{kind: :put, key_expr: "key/expr/1", payload: "payload"}]} =
             Task.await(task)
  end

  test "reply_error/3", context do
    task =
      Task.async(Zenohex.Session, :get, [
        context.session_id,
        "key/expr/**",
        100
      ])

    assert_receive %Zenohex.Query{zenoh_query: zenoh_query}

    assert :ok = Zenohex.Query.reply_error(zenoh_query, "payload")

    assert {:ok, [%Zenohex.Query.ReplyError{payload: "payload"}]} = Task.await(task)
  end

  test "reply_delete/3", context do
    task =
      Task.async(Zenohex.Session, :get, [
        context.session_id,
        "key/expr/**",
        100
      ])

    assert_receive %Zenohex.Query{zenoh_query: zenoh_query}

    assert :ok = Zenohex.Query.reply_delete(zenoh_query, "key/expr/1")

    assert {:ok, [%Zenohex.Sample{kind: :delete, key_expr: "key/expr/1"}]} = Task.await(task)
  end
end
