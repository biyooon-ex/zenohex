defmodule Zenohex.Examples.PullSubscriberTest do
  use ExUnit.Case

  alias Zenohex.Examples.PullSubscriber
  alias Zenohex.Session
  alias Zenohex.Sample

  test "start_link/1" do
    {:ok, session} = Zenohex.open()
    key_expr = "key/expression/**"

    me = self()
    callback = fn sample -> send(me, sample) end

    start_supervised!(
      {PullSubscriber, %{session: session, key_expr: key_expr, callback: callback}}
    )

    Session.put(session, "key/expression/put", "put")

    assert_receive(%Sample{key_expr: "key/expression/put", value: "put"})
  end

  test "pull/0" do
    {:ok, session} = Zenohex.open()
    key_expr = "key/expression/**"

    me = self()
    callback = fn sample -> send(me, sample) end

    start_supervised!(
      {PullSubscriber, %{session: session, key_expr: key_expr, callback: callback}}
    )

    Session.put(session, "key/expression/put", "put")

    assert_receive(%Sample{key_expr: "key/expression/put", value: "put"})
    refute_receive(%Sample{key_expr: "key/expression/put", value: "put"})
    PullSubscriber.pull()
    assert_receive(%Sample{key_expr: "key/expression/put", value: "put"})
  end
end
