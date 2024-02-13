defmodule Zenohex.Examples.SessionTest do
  use ExUnit.Case

  alias Zenohex.Examples.Session
  alias Zenohex.Examples.Subscriber
  alias Zenohex.Examples.Queryable
  alias Zenohex.Query
  alias Zenohex.Sample

  setup do
    start_supervised!({Session, %{}})

    # NOTE: Use the same session for Subscriber or Queryable, to run unit tests even if you only have a loopback interface.
    #
    #       - If you only have a loopback interface(lo), the test will always fail if you use different sessions.
    #         Because the peer cannot scout the another peer on lo.
    #       - Even if you have a network interface other than loopback,
    #         using different sessions may cause the test to fail depending on the scouting.

    %{session: Session.session()}
  end

  describe "put/2" do
    test "with subscriber", %{session: session} do
      me = self()

      start_supervised!(
        {Subscriber,
         %{
           session: session,
           key_expr: "key/expression/**",
           callback: fn sample -> send(me, sample) end
         }}
      )

      assert Session.put("key/expression/put", "value") == :ok
      assert_receive %Sample{key_expr: "key/expression/put", value: "value"}
    end
  end

  describe "delete/1" do
    test "with subscriber", %{session: session} do
      me = self()

      start_supervised!(
        {Subscriber,
         %{
           session: session,
           key_expr: "key/expression/**",
           callback: fn sample -> send(me, sample) end
         }}
      )

      assert Session.delete("key/expression/delete") == :ok
      assert_receive %Sample{key_expr: "key/expression/delete", kind: :delete}
    end
  end

  describe "get/2" do
    test "without queryable" do
      me = self()
      callback = fn sample -> send(me, sample) end
      :ok = Session.set_disconnected_cb(fn -> send(me, :disconnected) end)

      assert Session.get("key/expression/**", callback) == :ok
      assert_receive :disconnected
    end

    test "with queryable", %{session: session} do
      start_supervised!(
        {Queryable,
         %{
           session: session,
           key_expr: "key/expression/**",
           callback: fn query ->
             :ok = Query.reply(query, %Sample{key_expr: "key/expression/reply"})
             :ok = Query.finish_reply(query)
           end
         }}
      )

      me = self()
      callback = fn sample -> send(me, sample) end

      assert Session.get("key/expression/**", callback) == :ok
      assert_receive %Sample{}
    end
  end
end
