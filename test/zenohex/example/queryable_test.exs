defmodule Zenohex.Example.QueryableTest do
  use ExUnit.Case

  setup do
    {:ok, session_id} =
      Zenohex.Config.default()
      |> Zenohex.Test.Support.TestHelper.scouting_delay(0)
      |> Zenohex.Session.open()

    %{session_id: session_id}
  end

  test "reply correctly", context do
    me = self()

    {:ok, _pid} =
      start_supervised(
        {Zenohex.Example.Queryable,
         [
           session_id: context.session_id,
           key_expr: "key/expr",
           callback: fn query -> send(me, query) end
         ]},
        restart: :temporary
      )

    {:ok, [%Zenohex.Sample{}]} = Zenohex.get("key/expr/**", 100)

    assert_receive %Zenohex.Query{}
  end
end
