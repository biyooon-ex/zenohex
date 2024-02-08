defmodule Zenohex.Examples.SessionServerTest do
  use ExUnit.Case

  alias Zenohex.Examples.Session
  alias Zenohex.Examples.Subscriber
  alias Zenohex.Examples.Queryable
  alias Zenohex.Query
  alias Zenohex.Sample

  setup do
    start_supervised!({Session.Server, nil})
    :ok
  end

  test "session/2" do
    assert is_reference(Session.Server.session())
  end

  describe "put/2" do
    test "with subscriber" do
      me = self()

      start_supervised!(
        {Subscriber.Server,
         %{
           session: Session.Server.session(),
           key_expr: "key/expression/**",
           callback: fn sample -> send(me, sample) end
         }}
      )

      assert Session.Server.put("key/expression/put", "value") == :ok
      assert_receive %Sample{key_expr: "key/expression/put", value: "value"}
    end
  end

  describe "delete/1" do
    test "with subscriber" do
      me = self()

      start_supervised!(
        {Subscriber.Server,
         %{
           session: Session.Server.session(),
           key_expr: "key/expression/**",
           callback: fn sample -> send(me, sample) end
         }}
      )

      assert Session.Server.delete("key/expression/delete") == :ok
      assert_receive %Sample{key_expr: "key/expression/delete", kind: :delete}
    end
  end

  describe "get/2" do
    test "without queryable" do
      me = self()
      callback = fn sample -> send(me, sample) end
      :ok = Session.Server.set_disconnected_cb(fn -> send(me, :disconnected) end)

      assert Session.Server.get("key/expression/**", callback) == :ok
      assert_receive :disconnected
    end

    test "with queryable" do
      start_supervised!(
        {Queryable.Server,
         %{
           session: Session.Server.session(),
           key_expr: "key/expression/**",
           callback: fn query ->
             :ok = Query.reply(query, %Sample{key_expr: "key/expression/reply"})
             :ok = Query.finish_reply(query)
           end
         }}
      )

      me = self()
      callback = fn sample -> send(me, sample) end

      assert Session.Server.get("key/expression/**", callback) == :ok
      assert_receive %Sample{}
    end
  end
end
