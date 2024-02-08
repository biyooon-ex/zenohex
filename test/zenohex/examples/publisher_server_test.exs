defmodule Zenohex.Examples.PublisherTest do
  use ExUnit.Case

  alias Zenohex.Examples.PublisherServer
  alias Zenohex.Examples.Subscriber
  alias Zenohex.Sample

  setup do
    {:ok, session} = Zenohex.open()
    key_expr = "key/expression/pub"
    start_supervised!({PublisherServer, %{session: session, key_expr: key_expr}})

    %{session: session}
  end

  describe "put/1" do
    test "with subscriber", %{session: session} do
      me = self()

      start_supervised!(
        {Subscriber.Server,
         %{
           session: session,
           key_expr: "key/expression/**",
           callback: fn sample -> send(me, sample) end
         }}
      )

      for i <- 0..100 do
        assert PublisherServer.put(i) == :ok
        assert_receive %Sample{key_expr: "key/expression/pub", kind: :put, value: ^i}
      end
    end
  end

  describe "delete/0" do
    test "with subscriber", %{session: session} do
      me = self()

      start_supervised!(
        {Subscriber.Server,
         %{
           session: session,
           key_expr: "key/expression/**",
           callback: fn sample -> send(me, sample) end
         }}
      )

      assert PublisherServer.delete() == :ok
      assert_receive %Sample{key_expr: "key/expression/pub", kind: :delete}
    end
  end

  test "congestion_control/1" do
    assert PublisherServer.congestion_control(:block) == :ok
    assert PublisherServer.put("put") == :ok
  end

  test "priority/1" do
    assert PublisherServer.priority(:real_time) == :ok
    assert PublisherServer.put("put") == :ok
  end
end
