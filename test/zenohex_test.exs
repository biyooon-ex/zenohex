defmodule ZenohexTest do
  use ExUnit.Case, async: true

  test "session_open/0" do
    assert {:ok, _session_id} = Zenohex.session_open()
  end

  test "session_close/0" do
    {:ok, session_id} = Zenohex.session_open()
    assert Zenohex.session_close(session_id) == :ok
  end
end
