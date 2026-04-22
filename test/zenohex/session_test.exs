defmodule Zenohex.SessionTest do
  use ExUnit.Case

  setup do
    {:ok, session_id} =
      Zenohex.Config.default()
      |> Zenohex.Test.Support.TestHelper.scouting_delay(0)
      |> Zenohex.Session.open()

    on_exit(fn -> :ok = Zenohex.Session.close(session_id) end)

    %{session_id: session_id}
  end

  test "open/0" do
    assert {:ok, session_id} = Zenohex.Session.open()

    # Use explicit cleanup here because relying on Drop was flaky on Windows CI.
    # Without this, Windows CI intermittently failed with the following error:
    #
    #   ** (MatchError) no match of right hand side value:
    #   {:error,
    #    "native/zenohex_nif/src\\session.rs:282: close operation timed out! at
    #    C:\\Users\\runneradmin\\.cargo\\registry\\src\\index.crates.io-1949cf8c6b5b557f\\zenoh-1.9.0\\src\\api\\builders\\close.rs:124."}
    :ok = Zenohex.Session.close(session_id)
  end

  test "open/1" do
    assert {:ok, session_id} =
             Zenohex.Config.default()
             |> Zenohex.Test.Support.TestHelper.scouting_delay(0)
             |> Zenohex.Session.open()

    # Use explicit cleanup here because relying on Drop was flaky on Windows CI.
    # Without this, Windows CI intermittently failed with the following error:
    #
    #   ** (MatchError) no match of right hand side value:
    #   {:error,
    #    "native/zenohex_nif/src\\session.rs:282: close operation timed out! at
    #    C:\\Users\\runneradmin\\.cargo\\registry\\src\\index.crates.io-1949cf8c6b5b557f\\zenoh-1.9.0\\src\\api\\builders\\close.rs:124."}
    :ok = Zenohex.Session.close(session_id)
  end

  test "close/1" do
    {:ok, session_id} = Zenohex.Session.open()
    assert Zenohex.Session.close(session_id) == :ok
    assert Zenohex.Session.close(session_id) == {:error, "session not found"}
  end

  test "put/3", context do
    assert Zenohex.Session.put(context.session_id, "key/expr", "payload") == :ok
  end

  test "delete/2", context do
    assert Zenohex.Session.delete(context.session_id, "key/expr") == :ok
  end

  test "delete/3 accepts timestamp", context do
    {:ok, subscriber_id} =
      Zenohex.Session.declare_subscriber(context.session_id, "key/expr", self())

    on_exit(fn -> :ok = Zenohex.Subscriber.undeclare(subscriber_id) end)

    {:ok, timestamp} = Zenohex.Session.new_timestamp(context.session_id)

    assert :ok =
             Zenohex.Session.delete(context.session_id, "key/expr", timestamp: timestamp)

    assert_receive %Zenohex.Sample{kind: :delete, key_expr: "key/expr", timestamp: ^timestamp}
  end

  test "get/3", context do
    assert {:error, _} = Zenohex.Session.get(context.session_id, "key/expr", 100)
  end

  test "new_timestamp/1", context do
    assert {:ok, zenoh_timestamp} = Zenohex.Session.new_timestamp(context.session_id)
    assert [timestamp, _zenoh_id_string] = String.split(zenoh_timestamp, "/")
    assert {:ok, %DateTime{}, 0} = DateTime.from_iso8601(timestamp)
  end

  test "info/1", context do
    assert {:ok, %Zenohex.Session.Info{}} = Zenohex.Session.info(context.session_id)
  end

  test "declare_publisher/2", context do
    assert {:ok, _publisher_id} =
             Zenohex.Session.declare_publisher(context.session_id, "key/expr")
  end

  test "declare_querier/2", context do
    assert {:ok, _querier_id} =
             Zenohex.Session.declare_querier(context.session_id, "key/expr")
  end
end
