defmodule Zenohex.Examples.SessionServerTest do
  use ExUnit.Case

  alias Zenohex.Examples.SessionServer
  alias Zenohex.Examples.QueryableServer
  alias Zenohex.Query
  alias Zenohex.Sample

  setup do
    start_supervised!({SessionServer, nil})
    :ok
  end

  test "session/2" do
    assert is_reference(SessionServer.session())
  end

  test "put/2" do
    assert SessionServer.put("key/expression", "value") == :ok
  end

  describe "get/2" do
    test "without queryable" do
      me = self()
      callback = fn sample -> send(me, sample) end
      :ok = SessionServer.set_disconnected_cb(fn -> send(me, :disconnected) end)

      assert SessionServer.get("key/expression/**", callback) == :ok
      assert_receive :disconnected
    end

    test "with queryable" do
      start_supervised!(
        {QueryableServer,
         %{
           session: SessionServer.session(),
           key_expr: "key/expression/**",
           callback: fn query -> Query.reply(query, %Sample{key_expr: "key/expression/reply"}) end
         }}
      )

      me = self()
      callback = fn sample -> send(me, sample) end

      assert SessionServer.get("key/expression/**", callback) == :ok
      assert_receive %Sample{}
    end
  end
end