defmodule Zenohex.QueryableTest do
  use ExUnit.Case

  setup do
    {:ok, session_id} =
      Zenohex.Config.default()
      |> Zenohex.Test.Support.TestHelper.scouting_delay(0)
      |> Zenohex.Session.open()

    on_exit(fn -> Zenohex.Session.close(session_id) end)

    {:ok, queryable_id} = Zenohex.Session.declare_queryable(session_id, "key/expr", self())

    %{
      session_id: session_id,
      queryable_id: queryable_id
    }
  end

  test "undeclare/1", context do
    assert :ok = Zenohex.Queryable.undeclare(context.queryable_id)

    # confirm already undeclare
    assert {:error, _} = Zenohex.Queryable.undeclare(context.queryable_id)
  end
end
