defmodule Zenohex.SessionTest do
  use ExUnit.Case

  alias Zenohex.Session

  test "open/0" do
    assert {:ok, _session_id} = Session.open()
  end

  test "close/0" do
    {:ok, session_id} = Zenohex.Session.open()
    assert Session.close(session_id) == :ok
  end

  test "put/3" do
    {:ok, session_id} = Zenohex.Session.open()
    assert Zenohex.Session.put(session_id, "key/expression", "payload") == :ok
    :ok = Session.close(session_id)
  end
end
