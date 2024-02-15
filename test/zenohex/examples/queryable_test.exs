defmodule Zenohex.Examples.QueryableTest do
  use ExUnit.Case

  require Logger

  alias Zenohex.Examples.Queryable

  test "start_link/1" do
    {:ok, session} = Zenohex.open()
    key_expr = "key/expression/**"

    me = self()
    callback = fn query -> send(me, query) end

    start_supervised!({Queryable, %{session: session, key_expr: key_expr, callback: callback}})

    Zenohex.Session.get_timeout(session, key_expr, 1000)

    assert_receive(%Zenohex.Query{})
  end
end
