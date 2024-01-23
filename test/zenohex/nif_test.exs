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

    test "declare_publisher/3", %{session: session} do
      assert is_reference(
               Nif.declare_publisher(session, "key/expression", congestion_control: :block)
             )

      assert is_reference(Nif.declare_publisher(session, "key/expression", priority: :realtime))
    end

    test "publisher_congestion_control/2", %{session: session} do
      publisher = Nif.declare_publisher(session, "key/expression")
      assert is_reference(Nif.publisher_congestion_control(publisher, :block))
    end

    test "publisher_priority/2", %{session: session} do
      publisher = Nif.declare_publisher(session, "key/expression")
      assert is_reference(Nif.publisher_priority(publisher, :realtime))
    end

    for {type, value} <- [
          {"integer", 0},
          {"float", 0.0},
          {"binary", :erlang.term_to_binary("binary")}
        ] do
      test "publisher_put_#{type}/2", %{session: session} do
        type = unquote(type)
        value = unquote(value)
        publisher = Nif.declare_publisher(session, "key/expression")
        assert apply(Nif, :"publisher_put_#{type}", [publisher, value]) == :ok
      end
    end

    test "publisher_delete/1", %{session: session} do
      publisher = Nif.declare_publisher(session, "key/expression")
      assert Nif.publisher_delete(publisher) == :ok
    end
  end

  describe "subscriber" do
    test "declare_subscriber/2", %{session: session} do
      assert is_reference(Nif.declare_subscriber(session, "key/expression"))
    end

    test "declare_subscriber/3", %{session: session} do
      assert is_reference(
               Nif.declare_subscriber(session, "key/expression", reliability: :reliable)
             )
    end

    test "subscriber_recv_timeout/1", %{session: session} do
      publisher = Nif.declare_publisher(session, "key/expression")
      subscriber = Nif.declare_subscriber(session, "key/expression")

      Nif.publisher_put_integer(publisher, 0)
      assert Nif.subscriber_recv_timeout(subscriber, 1000) == 0

      Nif.publisher_put_float(publisher, 0.0)
      assert Nif.subscriber_recv_timeout(subscriber, 1000) == 0.0

      Nif.publisher_put_binary(publisher, "binary")
      assert Nif.subscriber_recv_timeout(subscriber, 1000) == "binary"

      assert Nif.subscriber_recv_timeout(subscriber, 1000) == :timeout
    end
  end

  describe "binary pub/sub" do
    setup context do
      key_expr = "key/expression"
      publisher = Nif.declare_publisher(context.session, key_expr)
      subscriber = Nif.declare_subscriber(context.session, key_expr)
      %{publisher: publisher, subscriber: subscriber}
    end

    for {test_name, binary} <- [
          {"empty binary", ""},
          {"erlang term binary", :erlang.term_to_binary(%URI{})}
        ] do
      test "#{test_name}", %{publisher: publisher, subscriber: subscriber} do
        binary = unquote(binary)
        Nif.publisher_put_binary(publisher, binary)
        assert Nif.subscriber_recv_timeout(subscriber, 1000) == binary
      end
    end
  end
end
