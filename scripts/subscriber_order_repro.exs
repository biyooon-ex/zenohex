defmodule SubscriberOrderRepro do
  @moduledoc """
  Issue #216 reproduction.

  Varies burst density by inter-message spacing and burst size so the order loss
  can be observed in the same script, matching the issue report's observed matrix.
  """

  @key_expr "sensor/*/observations"

  @cases [
    %{spacing_ms: 0, burst_count: 20, messages_per_burst: 100},
    %{spacing_ms: 5, burst_count: 3, messages_per_burst: 100},
    %{spacing_ms: 50, burst_count: 2, messages_per_burst: 100}
  ]

  def run do
    Enum.each(@cases, fn %{spacing_ms: spacing_ms, burst_count: burst_count, messages_per_burst: messages_per_burst} = scenario ->
      IO.puts("=== spacing=#{spacing_ms}ms burst_count=#{burst_count} messages_per_burst=#{messages_per_burst} ===")

      result = run_case(scenario)

      IO.puts("received=#{result.received}")
      IO.puts("inversions=#{result.inversions}")

      if result.inversions > 0 do
        IO.puts("ordering issue reproduced")
      else
        IO.puts("no inversion observed for this scenario")
      end

      IO.puts("")
    end)
  end

  defp run_case(%{spacing_ms: spacing_ms, burst_count: burst_count, messages_per_burst: messages_per_burst}) do
    config =
      Zenohex.Config.default()
      |> config_with_scouting_delay(0)

    {:ok, subscriber_session_id} = Zenohex.Session.open(config)
    {:ok, publisher_session_id} = Zenohex.Session.open(config)

    {:ok, subscriber_id} =
      Zenohex.Session.declare_subscriber(subscriber_session_id, @key_expr, self())

    {:ok, publisher_id} =
      Zenohex.Session.declare_publisher(publisher_session_id, "sensor/foo/observations")

    try do
      Process.sleep(500)

      publish_bursts(publisher_id, burst_count, messages_per_burst, spacing_ms)

      expected = burst_count * messages_per_burst
      received = collect_received(expected)

      %{
        received: length(received),
        inversions: count_inversions(received)
      }
    after
      _ = Zenohex.Subscriber.undeclare(subscriber_id)
      _ = Zenohex.Publisher.undeclare(publisher_id)
      _ = Zenohex.Session.close(subscriber_session_id)
      _ = Zenohex.Session.close(publisher_session_id)
    end
  end

  defp config_with_scouting_delay(config, delay) do
    {:ok, updated} =
      Zenohex.Config.insert_json5(config, "scouting/delay", Integer.to_string(delay))

    updated
  end

  defp publish_bursts(_publisher_id, burst_no, _messages_per_burst, _spacing_ms)
       when burst_no <= 0,
       do: :ok

  defp publish_bursts(publisher_id, burst_no, messages_per_burst, spacing_ms) do
    # Emit bursts in ascending logical order. If we publish the current burst
    # before the recursive tail, the overall stream becomes descending by burst and
    # creates false inversions unrelated to the callback path under test.
    publish_bursts(publisher_id, burst_no - 1, messages_per_burst, spacing_ms)

    publish_burst(
      publisher_id,
      (burst_no - 1) * messages_per_burst + 1,
      messages_per_burst,
      spacing_ms
    )
  end

  defp publish_burst(_publisher_id, _start_seq, messages_remaining, _spacing_ms)
       when messages_remaining <= 0,
       do: :ok

  defp publish_burst(publisher_id, start_seq, messages_remaining, spacing_ms) do
    payload = ~s({"seq":#{start_seq}})
    :ok = Zenohex.Publisher.put(publisher_id, payload)
    Process.sleep(spacing_ms)

    publish_burst(publisher_id, start_seq + 1, messages_remaining - 1, spacing_ms)
  end

  defp collect_received(expected, acc \\ []) do
    if length(acc) >= expected do
      Enum.reverse(acc)
    else
      receive do
        %Zenohex.Sample{payload: payload} ->
          case Jason.decode(payload) do
            {:ok, %{"seq" => seq}} -> collect_received(expected, [seq | acc])
            _ -> collect_received(expected, acc)
          end
      after
        5_000 ->
          Enum.reverse(acc)
      end
    end
  end

  defp count_inversions(sequence) do
    sequence
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.reduce(0, fn
      [prev, next], acc when next < prev -> acc + 1
      _, acc -> acc
    end)
  end
end

SubscriberOrderRepro.run()
