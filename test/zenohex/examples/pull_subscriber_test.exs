defmodule Zenohex.Examples.PullSubscriberTest do
  use ExUnit.Case

  import Zenohex.Test.Utils, only: [maybe_different_session: 1]

  alias Zenohex.Examples.PullSubscriber

  setup do
    {:ok, session} = Zenohex.open()
    key_expr = "key/expression/**"
    me = self()
    callback = fn sample -> send(me, sample) end

    start_supervised!(
      {PullSubscriber, %{session: session, key_expr: key_expr, callback: callback}}
    )

    %{session: maybe_different_session(session)}
  end

  # WHY: skip this test when using different session
  # When using same session, Zenoh pull subscriber can get Sample before pulling.
  # But using different session, Zenoh pull subscriber can not.
  # This might be a Zenoh bug.
  @tag System.get_env("USE_DIFFERENT_SESSION") && :skip
  test "start_link/1", %{session: session} do
    Zenohex.Session.put(session, "key/expression/put", "put")

    assert_receive(%Zenohex.Sample{key_expr: "key/expression/put", value: "put"})
  end

  test "pull/0", %{session: session} do
    Zenohex.Session.put(session, "key/expression/put", "put")

    PullSubscriber.pull()
    assert_receive(%Zenohex.Sample{key_expr: "key/expression/put", value: "put"})
  end
end
