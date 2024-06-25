defmodule Zenohex.Examples.SessionTest do
  use ExUnit.Case

  import Zenohex.Test.Utils, only: [maybe_different_session: 1]

  alias Zenohex.Examples.Session
  alias Zenohex.Examples.Subscriber
  alias Zenohex.Examples.Queryable

  setup do
    {:ok, session} = Zenohex.open()

    start_supervised!({Session, %{session: session}})

    %{session: maybe_different_session(session)}
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

      # This sleep is used to delegate asynchronous processing to Zenoh beyond the NIF.
      Process.sleep(1)

      assert Session.put("key/expression/put", "value") == :ok
      assert_receive %Zenohex.Sample{key_expr: "key/expression/put", value: "value"}
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

        # This sleep is used to delegate asynchronous processing to Zenoh beyond the NIF.
      Process.sleep(1)

      assert Session.delete("key/expression/delete") == :ok
      assert_receive %Zenohex.Sample{key_expr: "key/expression/delete", kind: :delete}
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
             :ok = Zenohex.Query.reply(query, %Zenohex.Sample{key_expr: "key/expression/reply"})
             :ok = Zenohex.Query.finish_reply(query)
           end
         }}
      )

      me = self()
      callback = fn sample -> send(me, sample) end

      assert Session.get("key/expression/**", callback) == :ok
      assert_receive %Zenohex.Sample{}
    end
  end
end
