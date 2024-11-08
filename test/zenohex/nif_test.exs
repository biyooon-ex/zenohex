defmodule Zenohex.NifTest do
  use ExUnit.Case

  alias Zenohex.Nif
  alias Zenohex.Sample

  setup_all do
    {:ok, session} = Nif.zenoh_open()
    %{session: session}
  end

  describe "session" do
    for {type, value} <- [
          {"integer", 0},
          {"float", +0.0},
          {"binary", :erlang.term_to_binary("binary")}
        ] do
      test "session_put_#{type}/2", %{session: session} do
        type = unquote(type)
        value = unquote(value)
        assert apply(Nif, :"session_put_#{type}", [session, "key/expression", value]) == :ok
      end
    end

    test "session_get_reply_receiver/3", %{session: session} do
      {:ok, receiver} = Nif.session_get_reply_receiver(session, "key_expression")
      assert is_reference(receiver)
    end

    test "session_get_reply_timeout/2", %{session: session} do
      {:ok, receiver} = Nif.session_get_reply_receiver(session, "key_expression")
      assert Nif.session_get_reply_timeout(receiver, 1000) == {:error, :disconnected}
    end

    test "session_delete/2", %{session: session} do
      assert Nif.session_delete(session, "key_expression") == :ok
    end
  end

  describe "publisher" do
    alias Zenohex.Publisher.Options

    test "declare_publisher/2", %{session: session} do
      {:ok, publisher} = Nif.declare_publisher(session, "key/expression")
      assert is_reference(publisher)
    end

    test "declare_publisher/3", %{session: session} do
      opts = %Options{congestion_control: :block, priority: :real_time}
      {:ok, publisher} = Nif.declare_publisher(session, "key/expression", opts)
      assert is_reference(publisher)
    end

    test "publisher_congestion_control/2", %{session: session} do
      {:ok, publisher} = Nif.declare_publisher(session, "key/expression")
      assert is_reference(Nif.publisher_congestion_control(publisher, :block))
    end

    test "publisher_priority/2", %{session: session} do
      {:ok, publisher} = Nif.declare_publisher(session, "key/expression")
      assert is_reference(Nif.publisher_priority(publisher, :real_time))
    end

    for {type, value} <- [
          {"integer", 0},
          {"float", +0.0},
          {"binary", :erlang.term_to_binary("binary")}
        ] do
      test "publisher_put_#{type}/2", %{session: session} do
        type = unquote(type)
        value = unquote(value)
        {:ok, publisher} = Nif.declare_publisher(session, "key/expression")
        assert apply(Nif, :"publisher_put_#{type}", [publisher, value]) == :ok
      end
    end

    test "publisher_delete/1", %{session: session} do
      {:ok, publisher} = Nif.declare_publisher(session, "key/expression")
      assert Nif.publisher_delete(publisher) == :ok
    end
  end

  describe "subscriber" do
    alias Zenohex.Subscriber.Options

    test "declare_subscriber/2", %{session: session} do
      {:ok, subscriber} = Nif.declare_subscriber(session, "key/expression")
      assert is_reference(subscriber)
    end

    test "declare_subscriber/3", %{session: session} do
      opts = %Options{reliability: :reliable}
      {:ok, subscriber} = Nif.declare_subscriber(session, "key/expression", opts)
      assert is_reference(subscriber)
    end

    test "subscriber_recv_timeout/1", %{session: session} do
      {:ok, publisher} = Nif.declare_publisher(session, "key/expression")
      {:ok, subscriber} = Nif.declare_subscriber(session, "key/expression")

      Nif.publisher_put_integer(publisher, 0)
      assert {:ok, %Sample{value: 0}} = Nif.subscriber_recv_timeout(subscriber, 1000)

      Nif.publisher_put_float(publisher, +0.0)
      assert {:ok, %Sample{value: +0.0}} = Nif.subscriber_recv_timeout(subscriber, 1000)

      Nif.publisher_put_binary(publisher, "binary")
      assert {:ok, %Sample{value: "binary"}} = Nif.subscriber_recv_timeout(subscriber, 1000)
      assert Nif.subscriber_recv_timeout(subscriber, 1000) == {:error, :timeout}
    end
  end

  describe "binary pub/sub" do
    setup context do
      key_expr = "key/expression"
      {:ok, publisher} = Nif.declare_publisher(context.session, key_expr)
      {:ok, subscriber} = Nif.declare_subscriber(context.session, key_expr)
      %{publisher: publisher, subscriber: subscriber}
    end

    for {test_name, binary} <- [
          {"empty binary", ""},
          {"erlang term binary", :erlang.term_to_binary(%URI{})}
        ] do
      test "#{test_name}", %{publisher: publisher, subscriber: subscriber} do
        binary = unquote(binary)
        Nif.publisher_put_binary(publisher, binary)
        assert {:ok, %Sample{value: ^binary}} = Nif.subscriber_recv_timeout(subscriber, 1000)
      end
    end
  end

  describe "queryable" do
    alias Zenohex.Queryable.Options

    test "declare_queryable/2", %{session: session} do
      {:ok, queryable} = Nif.declare_queryable(session, "key/expression")
      assert is_reference(queryable)
    end

    test "declare_queryable/3", %{session: session} do
      opts = %Options{complete: true}
      {:ok, queryable} = Nif.declare_queryable(session, "key/expression", opts)
      assert is_reference(queryable)
    end
  end

  describe "key_expr" do
    test "key_expr_intersects/2" do
      assert Nif.key_expr_intersects("key/expression/**", "key/expression/demo")
      assert Nif.key_expr_intersects("key/expression/demo", "key/expression/**")
      refute Nif.key_expr_intersects("key/expression/**", "key/value")
      refute Nif.key_expr_intersects("key/value", "key/expression/**")
    end
  end
end
