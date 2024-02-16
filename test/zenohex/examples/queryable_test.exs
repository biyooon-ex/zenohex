defmodule Zenohex.Examples.QueryableTest do
  use ExUnit.Case

  import Zenohex.Test.Utils, only: [maybe_different_session: 1]

  alias Zenohex.Examples.Queryable

  setup do
    {:ok, session} = Zenohex.open()
    key_expr = "key/expression/**"
    me = self()
    callback = fn query -> send(me, query) end

    start_supervised!({Queryable, %{session: session, key_expr: key_expr, callback: callback}})

    %{session: maybe_different_session(session)}
  end

  test "start_link/1", %{session: session} do
    Zenohex.Session.get_timeout(session, "key/expression/**", 1000)

    assert_receive(%Zenohex.Query{})
  end
end
