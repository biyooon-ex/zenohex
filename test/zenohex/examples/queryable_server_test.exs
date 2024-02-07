defmodule Zenohex.Examples.QueryableServerTest do
  use ExUnit.Case

  require Logger

  alias Zenohex.Examples.QueryableServer
  alias Zenohex.Session
  alias Zenohex.Query

  test "start_link/1" do
    {:ok, session} = Zenohex.open()
    key_expr = "key/expression/**"

    me = self()
    callback = fn query -> send(me, query) end

    start_supervised!(
      {QueryableServer, %{session: session, key_expr: key_expr, callback: callback}}
    )

    Session.get_timeout(session, key_expr, 1000)

    assert_receive(%Query{})
  end
end
