defmodule Zenohex.SessionTest do
  use ExUnit.Case

  alias Zenohex.Session

  test "open/0" do
    assert {:ok, _session_id} = Session.open()
  end

  test "close/0" do
    {:ok, session_id} = Zenohex.Session.open()
    assert Session.close(session_id) == :ok
    assert Session.close(session_id) == {:error, "session not found"}
  end

  test "put/3" do
    {:ok, session_id} = Zenohex.Session.open()
    assert Zenohex.Session.put(session_id, "key/expr", "payload") == :ok
  end

  test "get/3" do
    {:ok, session_id} = Zenohex.Session.open()
    assert {:error, _} = Zenohex.Session.get(session_id, "key/expr", 100)
  end

  test "declare_publisher/2" do
    {:ok, session_id} = Zenohex.Session.open()
    assert {:ok, _publisher_id} = Zenohex.Session.declare_publisher(session_id, "key/expr")
  end
end
