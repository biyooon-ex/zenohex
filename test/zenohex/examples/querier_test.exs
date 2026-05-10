defmodule Zenohex.Examples.QuerierTest do
  use ExUnit.Case

  setup do
    {:ok, session_id} =
      Zenohex.Config.default()
      |> Zenohex.Test.Support.TestHelper.scouting_delay(0)
      |> Zenohex.Session.open()

    {:ok, queryable_id} = Zenohex.Session.declare_queryable(session_id, "key/expr/**", self())

    on_exit(fn ->
      :ok = Zenohex.Queryable.undeclare(queryable_id)
      :ok = Zenohex.Session.close(session_id)
    end)

    %{session_id: session_id}
  end

  test "example works correctly", context do
    assert {:ok, _pid} =
             Zenohex.Examples.Querier.start_link(
               session_id: context.session_id,
               key_expr: "key/expr/**"
             )

    task = Task.async(fn -> Zenohex.Examples.Querier.get(timeout: 100, payload: "payload") end)

    assert_receive %Zenohex.Query{zenoh_query: zenoh_query, payload: "payload"}

    assert :ok = Zenohex.Query.reply(zenoh_query, "key/expr/1", "reply")

    assert {:ok, [%Zenohex.Sample{kind: :put, key_expr: "key/expr/1", payload: "reply"}]} =
             Task.await(task)

    assert :ok = Zenohex.Examples.Querier.stop()
  end
end
