defmodule Zenohex.SessionTest do
  use ExUnit.Case

  setup do
    {:ok, session_id} =
      Zenohex.Config.default()
      |> Zenohex.Test.Support.TestHelper.scouting_delay(0)
      |> Zenohex.Session.open()

    on_exit(fn -> Zenohex.Session.close(session_id) end)

    %{session_id: session_id}
  end

  test "open/0" do
    assert {:ok, _session_id} = Zenohex.Session.open()
  end

  test "open/1" do
    assert {:ok, _session_id} =
             Zenohex.Config.default()
             |> Zenohex.Test.Support.TestHelper.scouting_delay(0)
             |> Zenohex.Session.open()
  end

  test "close/0", context do
    session_id = context.session_id
    assert Zenohex.Session.close(session_id) == :ok
    assert Zenohex.Session.close(session_id) == {:error, "session not found"}
  end

  test "put/3", context do
    session_id = context.session_id
    assert Zenohex.Session.put(session_id, "key/expr", "payload") == :ok
  end

  test "get/3", context do
    session_id = context.session_id
    assert {:error, _} = Zenohex.Session.get(session_id, "key/expr", 100)
  end

  test "declare_publisher/2", context do
    session_id = context.session_id
    assert {:ok, _publisher_id} = Zenohex.Session.declare_publisher(session_id, "key/expr")
  end
end
