defmodule Zenohex.ChannelConfigTest do
  use ExUnit.Case

  setup do
    previous_kind = Application.get_env(:zenohex, :channel_kind)
    previous_capacity = Application.get_env(:zenohex, :channel_capacity)

    on_exit(fn ->
      restore(:channel_kind, previous_kind)
      restore(:channel_capacity, previous_capacity)
    end)
  end

  defp restore(key, nil), do: Application.delete_env(:zenohex, key)
  defp restore(key, value), do: Application.put_env(:zenohex, key, value)

  test "get/0 defaults to :fifo with capacity 256" do
    Application.delete_env(:zenohex, :channel_kind)
    Application.delete_env(:zenohex, :channel_capacity)

    assert Zenohex.ChannelConfig.get() == {:fifo, 256}
  end

  test "get/0 honors a configured :ring channel_kind" do
    Application.put_env(:zenohex, :channel_kind, :ring)

    assert Zenohex.ChannelConfig.get() == {:ring, 256}
  end

  test "get/0 honors a configured channel_capacity" do
    Application.put_env(:zenohex, :channel_capacity, 8)

    assert Zenohex.ChannelConfig.get() == {:fifo, 8}
  end

  test "get/0 raises on an invalid channel_kind" do
    Application.put_env(:zenohex, :channel_kind, :bogus)

    assert_raise ArgumentError, ~r/invalid :channel_kind/, fn ->
      Zenohex.ChannelConfig.get()
    end
  end

  test "get/0 raises on a non-positive channel_capacity" do
    Application.put_env(:zenohex, :channel_capacity, 0)

    assert_raise ArgumentError, ~r/invalid :channel_capacity/, fn ->
      Zenohex.ChannelConfig.get()
    end
  end

  test "declare_subscriber/4 still delivers messages when configured with :ring" do
    Application.put_env(:zenohex, :channel_kind, :ring)

    {:ok, session_id} =
      Zenohex.Config.default()
      |> Zenohex.Test.Support.TestHelper.scouting_delay(0)
      |> Zenohex.Session.open()

    on_exit(fn -> :ok = Zenohex.Session.close(session_id) end)

    {:ok, subscriber_id} =
      Zenohex.Session.declare_subscriber(session_id, "channel_config/ring", self())

    on_exit(fn -> :ok = Zenohex.Subscriber.undeclare(subscriber_id) end)

    Process.sleep(500)

    assert :ok = Zenohex.Session.put(session_id, "channel_config/ring", "hello")
    assert_receive %Zenohex.Sample{payload: "hello"}, 5_000
  end

  test "declare_subscriber/4 raises ArgumentError for an invalid configured channel_kind" do
    Application.put_env(:zenohex, :channel_kind, :bogus)

    {:ok, session_id} =
      Zenohex.Config.default()
      |> Zenohex.Test.Support.TestHelper.scouting_delay(0)
      |> Zenohex.Session.open()

    on_exit(fn -> :ok = Zenohex.Session.close(session_id) end)

    assert_raise ArgumentError, ~r/invalid :channel_kind/, fn ->
      Zenohex.Session.declare_subscriber(session_id, "channel_config/invalid", self())
    end
  end

  test "warns when a full :fifo channel blocks Zenoh's callback" do
    Application.put_env(:zenohex, :channel_capacity, 1)
    flood_and_assert_warning("channel_config/fifo_full", "fifo channel is full")
  end

  test "warns when a full :ring channel drops a sample" do
    Application.put_env(:zenohex, :channel_kind, :ring)
    Application.put_env(:zenohex, :channel_capacity, 1)
    flood_and_assert_warning("channel_config/ring_drop", "ring channel full, dropped")
  end

  # WHY: a single publisher process paces itself (each `put/2` round-trips
  #      synchronously), so it never actually fills a small channel; several
  #      concurrent publishers are needed to race ahead of the forwarder.
  defp flood_and_assert_warning(key_expr, expected_message) do
    :ok = Zenohex.Nif.nif_logger_init(self(), :warning)
    :ok = Zenohex.Nif.Logger.enable()
    # WHY: other test modules can leave the logger's target broadened to
    #      "zenoh" (matches both crates by prefix), so pin it back here or an
    #      unrelated Zenoh-internal warning can race ahead of ours below.
    :ok = Zenohex.Nif.Logger.set_target("zenohex_nif")
    on_exit(fn -> Zenohex.Nif.Logger.disable() end)

    {:ok, session_id} =
      Zenohex.Config.default()
      |> Zenohex.Test.Support.TestHelper.scouting_delay(0)
      |> Zenohex.Session.open()

    on_exit(fn -> :ok = Zenohex.Session.close(session_id) end)

    {:ok, subscriber_id} = Zenohex.Session.declare_subscriber(session_id, key_expr, self())
    on_exit(fn -> :ok = Zenohex.Subscriber.undeclare(subscriber_id) end)

    {:ok, publisher_id} = Zenohex.Session.declare_publisher(session_id, key_expr)
    on_exit(fn -> :ok = Zenohex.Publisher.undeclare(publisher_id) end)

    Process.sleep(500)

    1..8
    |> Task.async_stream(
      fn _ -> Enum.each(1..20, &Zenohex.Publisher.put(publisher_id, "msg#{&1}")) end,
      max_concurrency: 8
    )
    |> Stream.run()

    assert_receive {:warning, message}, 5_000
    assert message =~ expected_message
  end
end
