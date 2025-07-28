defmodule Zenohex.Examples.QueryableTest do
  use ExUnit.Case

  setup do
    {:ok, session_id} =
      Zenohex.Config.default()
      |> Zenohex.Test.Support.TestHelper.scouting_delay(0)
      |> Zenohex.Session.open()

    %{
      me: self(),
      session_id: session_id,
      key_expr: "key/expr"
    }
  end

  test "example works correctly", context do
    {:ok, _pid} =
      Zenohex.Examples.Queryable.start_link(
        session_id: context.session_id,
        key_expr: context.key_expr,
        callback: &Zenohex.Query.reply(&1.zenoh_query, context.key_expr, "reply")
      )

    {:ok, [%Zenohex.Sample{payload: "reply"}]} = Zenohex.get(context.key_expr, 100)

    assert :ok = Zenohex.Examples.Queryable.stop()
  end
end
