defmodule Zenohex.Example.QueryableTest do
  use ExUnit.Case

  test "reply correctly" do
    me = self()

    {:ok, _pid} =
      start_supervised(
        {Zenohex.Example.Queryable,
         [
           key_expr: "key/expr",
           callback: fn query -> send(me, query) end
         ]},
        restart: :temporary
      )

    {:ok, [%Zenohex.Sample{}]} = Zenohex.get("key/expr/**", 100)

    assert_receive %Zenohex.Query{}
  end
end
