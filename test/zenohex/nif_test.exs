defmodule Zenohex.NifTest do
  use ExUnit.Case

  alias Zenohex.Nif

  test "add/2" do
    assert Nif.add(1, 2) == 3
  end

  test "test_thread/0" do
    pid = self()
    assert Nif.test_thread() == :ok
    assert_receive ^pid
  end

  setup_all do
    %{session: Nif.zenoh_open()}
  end

  describe "publisher" do
    test "declare_publisher/2", %{session: session} do
      assert is_reference(Nif.declare_publisher(session, "key/expression"))
    end

    for {type, value} <- [{"string", "value"}, {"integer", 0}, {"float", 0.0}] do
      test "publisher_put_#{type}/2", %{session: session} do
        type = unquote(type)
        value = unquote(value)
        publisher = Nif.declare_publisher(session, "key/expression")
        assert apply(Nif, :"publisher_put_#{type}", [publisher, value]) == :ok
      end
    end
  end

  describe "subscriber" do
    test "declare_subscriber/2", %{session: session} do
      assert is_reference(Nif.declare_subscriber(session, "key/expression"))
    end

    test "subscriber_recv_timeout/1", %{session: session} do
      publisher = Nif.declare_publisher(session, "key/expression")
      subscriber = Nif.declare_subscriber(session, "key/expression")

      Nif.publisher_put_string(publisher, "value")
      assert Nif.subscriber_recv_timeout(subscriber, 1000) == "value"

      Nif.publisher_put_integer(publisher, 0)
      assert Nif.subscriber_recv_timeout(subscriber, 1000) == 0

      Nif.publisher_put_float(publisher, 0.0)
      assert Nif.subscriber_recv_timeout(subscriber, 1000) == 0.0

      assert Nif.subscriber_recv_timeout(subscriber, 1000) == :timeout
    end
  end
end
