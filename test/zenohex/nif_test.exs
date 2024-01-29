defmodule Zenohex.NifTest do
  use ExUnit.Case, async: true

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

  describe "session" do
    for {type, value} <- [
          {"integer", 0},
          {"float", 0.0},
          {"binary", :erlang.term_to_binary("binary")}
        ] do
      test "session_put_#{type}/2", %{session: session} do
        type = unquote(type)
        value = unquote(value)
        assert apply(Nif, :"session_put_#{type}", [session, "key/expression", value]) == :ok
      end
    end

    test "session_get_timeout/3", %{session: session} do
      assert Nif.session_get_timeout(session, "key_expression", 1000) == :timeout
    end

    test "session_delete/2", %{session: session} do
      assert Nif.session_delete(session, "key_expression") == :ok
    end
  end

  describe "publisher" do
    alias Zenohex.Publisher.Options

    test "declare_publisher/2", %{session: session} do
      assert is_reference(Nif.declare_publisher(session, "key/expression"))
    end

    test "declare_publisher/3", %{session: session} do
      opts = %Options{congestion_control: :block, priority: :real_time}
      assert is_reference(Nif.declare_publisher(session, "key/expression", opts))
    end

    test "publisher_congestion_control/2", %{session: session} do
      publisher = Nif.declare_publisher(session, "key/expression")
      assert is_reference(Nif.publisher_congestion_control(publisher, :block))
    end

    test "publisher_priority/2", %{session: session} do
      publisher = Nif.declare_publisher(session, "key/expression")
      assert is_reference(Nif.publisher_priority(publisher, :real_time))
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
    alias Zenohex.Subscriber.Options

    test "declare_subscriber/2", %{session: session} do
      assert is_reference(Nif.declare_subscriber(session, "key/expression"))
    end

    test "declare_subscriber/3", %{session: session} do
      opts = %Options{reliability: :reliable}
      assert is_reference(Nif.declare_subscriber(session, "key/expression", opts))
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

  describe "pull subscriber" do
    alias Zenohex.Subscriber.Options

    test "declare_pull_subscriber/2", %{session: session} do
      assert is_reference(Nif.declare_pull_subscriber(session, "key/expression"))
    end

    test "declare_pull_subscriber/3", %{session: session} do
      opts = %Options{reliability: :reliable}
      assert is_reference(Nif.declare_pull_subscriber(session, "key/expression", opts))
    end

    test "pull_subscriber_pull/1", %{session: session} do
      publisher = Nif.declare_publisher(session, "key/expression")
      pull_subscriber = Nif.declare_pull_subscriber(session, "key/expression")

      :ok = Nif.publisher_put_integer(publisher, 0)
      0 = Nif.pull_subscriber_recv_timeout(pull_subscriber, 1000)
      :timeout = Nif.pull_subscriber_recv_timeout(pull_subscriber, 1000)
      assert Nif.pull_subscriber_pull(pull_subscriber) == :ok
      assert Nif.pull_subscriber_recv_timeout(pull_subscriber, 1000) == 0
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

  describe "queryable" do
    alias Zenohex.Queryable.Options

    test "declare_queryable/2", %{session: session} do
      assert is_reference(Nif.declare_queryable(session, "key/expression"))
    end

    test "declare_queryable/3", %{session: session} do
      opts = %Options{complete: true}
      assert is_reference(Nif.declare_queryable(session, "key/expression", opts))
    end
  end
end
