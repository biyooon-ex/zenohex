defmodule Zenohex.QuerierTest do
  use ExUnit.Case

  setup do
    {:ok, session_id} =
      Zenohex.Config.default()
      |> Zenohex.Test.Support.TestHelper.scouting_delay(0)
      |> Zenohex.Session.open()

    {:ok, queryable_id} = Zenohex.Session.declare_queryable(session_id, "key/expr/**", self())
    {:ok, querier_id} = Zenohex.Session.declare_querier(session_id, "key/expr/**")

    on_exit(fn ->
      :ok = Zenohex.Queryable.undeclare(queryable_id)
      :ok = Zenohex.Querier.undeclare(querier_id)
      :ok = Zenohex.Session.close(session_id)
    end)

    %{
      session_id: session_id,
      querier_id: querier_id,
      queryable_id: queryable_id
    }
  end

  test "undeclare/1", context do
    {:ok, querier_id} = Zenohex.Session.declare_querier(context.session_id, "key/expr/1")
    assert :ok = Zenohex.Querier.undeclare(querier_id)
    assert {:error, _} = Zenohex.Querier.undeclare(querier_id)
  end

  test "get/3 returns put replies", context do
    task = Task.async(Zenohex.Querier, :get, [context.querier_id, 100])

    assert_receive %Zenohex.Query{zenoh_query: zenoh_query}

    assert :ok = Zenohex.Query.reply(zenoh_query, "key/expr/1", "payload")

    assert {:ok, [%Zenohex.Sample{kind: :put, key_expr: "key/expr/1", payload: "payload"}]} =
             Task.await(task)
  end

  test "get/3 returns error replies", context do
    task = Task.async(Zenohex.Querier, :get, [context.querier_id, 100])

    assert_receive %Zenohex.Query{zenoh_query: zenoh_query}

    assert :ok = Zenohex.Query.reply_error(zenoh_query, "payload")

    assert {:ok, [%Zenohex.Query.ReplyError{payload: "payload"}]} = Task.await(task)
  end

  test "get/3 forwards payload and parameters", context do
    task =
      Task.async(Zenohex.Querier, :get, [
        context.querier_id,
        100,
        [payload: "payload", parameters: "key=value"]
      ])

    assert_receive %Zenohex.Query{
      zenoh_query: zenoh_query,
      payload: "payload",
      parameters: "key=value"
    }

    assert :ok = Zenohex.Query.reply(zenoh_query, "key/expr/1", "payload")

    assert {:ok, [%Zenohex.Sample{key_expr: "key/expr/1", payload: "payload"}]} =
             Task.await(task)
  end

  test "get_async/2 delivers put replies to pid", context do
    assert :ok = Zenohex.Querier.get_async(context.querier_id, self())

    assert_receive %Zenohex.Query{zenoh_query: zenoh_query}
    assert :ok = Zenohex.Query.reply(zenoh_query, "key/expr/1", "async_payload")

    assert_receive %Zenohex.Sample{kind: :put, key_expr: "key/expr/1", payload: "async_payload"}
  end

  test "get_async/2 delivers error replies to pid", context do
    assert :ok = Zenohex.Querier.get_async(context.querier_id, self())

    assert_receive %Zenohex.Query{zenoh_query: zenoh_query}
    assert :ok = Zenohex.Query.reply_error(zenoh_query, "error_payload")

    assert_receive %Zenohex.Query.ReplyError{payload: "error_payload"}
  end
end
