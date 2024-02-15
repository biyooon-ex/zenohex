defmodule Zenohex.Examples.SubscriberTest do
  use ExUnit.Case

  alias Zenohex.Examples.Subscriber

  test "start_link/1" do
    {:ok, session} = Zenohex.open()
    key_expr = "key/expression/**"

    me = self()
    callback = fn sample -> send(me, sample) end

    start_supervised!({Subscriber, %{session: session, key_expr: key_expr, callback: callback}})

    Zenohex.Session.put(session, "key/expression/put", "put")

    assert_receive(%Zenohex.Sample{key_expr: "key/expression/put", value: "put"})
  end
end
