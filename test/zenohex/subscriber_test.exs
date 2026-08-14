defmodule Zenohex.SubscriberTest do
  use ExUnit.Case

  setup do
    {:ok, session_id} =
      Zenohex.Config.default()
      |> Zenohex.Test.Support.TestHelper.scouting_delay(0)
      |> Zenohex.Session.open()

    on_exit(fn -> :ok = Zenohex.Session.close(session_id) end)

    {:ok, subscriber_id} = Zenohex.Session.declare_subscriber(session_id, "key/expr", self())

    %{
      session_id: session_id,
      subscriber_id: subscriber_id
    }
  end

  test "undeclare/1", context do
    assert :ok = Zenohex.Subscriber.undeclare(context.subscriber_id)

    # confirm already undeclared
    assert {:error, _} = Zenohex.Subscriber.undeclare(context.subscriber_id)
  end

  test "preserves receive order under bursty delivery", context do
    # Regression for issue #216.
    # A single subscriber must not reorder samples from one key expression when a
    # burst arrives back-to-back. This is intentionally close to the real-world
    # reproducer: we publish a series of serialized messages to one key and assert
    # that the subscriber pid observes the same sequence in the same order.
    #
    # We keep this inside the subscriber test module because it exercises the
    # public subscriber/session API directly, and it shares the same lifecycle and
    # setup patterns as the other subscriber tests.
    {:ok, publisher_session_id} =
      Zenohex.Config.default()
      |> Zenohex.Test.Support.TestHelper.scouting_delay(0)
      |> Zenohex.Session.open()

    on_exit(fn ->
      :ok = Zenohex.Session.close(publisher_session_id)
    end)

    {:ok, publisher_id} =
      Zenohex.Session.declare_publisher(publisher_session_id, "sensor/alpha/observations")

    on_exit(fn ->
      :ok = Zenohex.Publisher.undeclare(publisher_id)
    end)

    {:ok, subscriber_id} =
      Zenohex.Session.declare_subscriber(context.session_id, "sensor/*/observations", self())

    on_exit(fn ->
      :ok = Zenohex.Subscriber.undeclare(subscriber_id)
    end)

    # Give the subscription time to become active before the first burst.
    # Without this warm-up, the initial publishes can race the subscription setup
    # and make the regression flaky even when the ordering bridge is correct.
    Process.sleep(500)

    drain_mailbox()

    burst_size = 100
    total_bursts = 20

    Enum.each(1..total_bursts, fn burst_index ->
      expected = Enum.to_list(((burst_index - 1) * burst_size + 1)..(burst_index * burst_size))

      Enum.each(expected, fn seq ->
        payload = ~s({"seq":#{seq}})
        assert :ok = Zenohex.Publisher.put(publisher_id, payload)
      end)

      received =
        collect_sequences(length(expected))
        |> Enum.map(fn %{"seq" => seq} -> seq end)

      assert received == expected,
             "burst #{burst_index} arrived out of order: expected=#{inspect(expected)} received=#{inspect(received)}"
    end)
  end

  defp drain_mailbox do
    # This is only a test hygiene step: it clears stale messages left in the
    # mailbox before the burst-order assertion starts. It does not explain the
    # race itself; the actual regression is the sequence check below.
    receive do
      %Zenohex.Sample{} -> drain_mailbox()
    after
      0 -> :ok
    end
  end

  defp collect_sequences(expected, acc \\ []) do
    if length(acc) >= expected do
      Enum.reverse(acc)
    else
      receive do
        %Zenohex.Sample{payload: payload} ->
          case Jason.decode(payload) do
            {:ok, %{"seq" => seq}} -> collect_sequences(expected, [%{"seq" => seq} | acc])
            {:error, _} -> collect_sequences(expected, acc)
          end
      after
        5_000 ->
          Enum.reverse(acc)
      end
    end
  end
end
