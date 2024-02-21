defmodule Zenohex.Examples.SubscriberTest do
  use ExUnit.Case

  import Zenohex.Test.Utils, only: [maybe_different_session: 1]

  alias Zenohex.Examples.Subscriber

  setup do
    {:ok, session} = Zenohex.open()
    key_expr = "key/expression/**"
    me = self()
    callback = fn sample -> send(me, sample) end

    start_supervised!({Subscriber, %{session: session, key_expr: key_expr, callback: callback}})

    %{session: maybe_different_session(session)}
  end

  test "start_link/1", %{session: session} do
    Zenohex.Session.put(session, "key/expression/put", "put")

    assert_receive(%Zenohex.Sample{key_expr: "key/expression/put", value: "put"})
  end
end
