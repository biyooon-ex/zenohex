defmodule ZenohexTest do
  use ExUnit.Case, async: true
  doctest Zenohex

  test "pub/sub" do
    {:ok, session} = Zenohex.open()
    {:ok, publisher} = Zenohex.Session.declare_publisher(session, "pub/sub")
    {:ok, subscriber} = Zenohex.Session.declare_subscriber(session, "pub/sub")

    for i <- 1..100 do
      :ok = Zenohex.Publisher.put(publisher, "Hello Zenoh Dragon #{i}")

      assert Zenohex.Subscriber.recv_timeout(subscriber, 1000) ==
               {:ok, "Hello Zenoh Dragon #{i}"}
    end
  end
end
