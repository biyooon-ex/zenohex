defmodule SchedulerCanary do
  @moduledoc """
  Ticks on its own `receive ... after` timer and records the gap between ticks.
  `Publisher.put/2` is a non-dirty NIF that blocks synchronously on `.wait()`;
  if enough concurrent callers get stuck on a full FifoChannel, they can tie up
  every regular BEAM scheduler, and this canary's ticks fall behind schedule
  because it can't get scheduled either. A large gap is indirect evidence of
  that scheduler starvation, not just of this one process being slow.
  """

  def start(interval_ms) do
    parent = self()
    spawn(fn -> loop(parent, interval_ms, System.monotonic_time(:millisecond), []) end)
  end

  def stop(pid) do
    send(pid, :stop)

    receive do
      {:canary_result, gaps} -> gaps
    after
      10_000 -> []
    end
  end

  defp loop(parent, interval_ms, last_tick_at, gaps) do
    receive do
      :stop -> send(parent, {:canary_result, Enum.reverse(gaps)})
    after
      interval_ms ->
        now = System.monotonic_time(:millisecond)
        loop(parent, interval_ms, now, [now - last_tick_at | gaps])
    end
  end
end

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
    %{spacing_ms: 50, burst_count: 2, messages_per_burst: 100},
    # WHY: a single burst well above CHANNEL_CAPACITY (256), published back-to-back
    #      with no spacing, so the native queue fills up during publishing itself
    #      (axis A: Fifo blocks the publisher/Zenoh side, Ring drops the oldest).
    %{spacing_ms: 0, burst_count: 1, messages_per_burst: 2000}
  ]

  @concurrent_flood %{producers: 8, messages_per_producer: 2000}
  @scheduler_stall_check %{producers: 32, messages_per_producer: 3000, canary_interval_ms: 20}

  def run do
    Enum.each(@cases, fn %{
                           spacing_ms: spacing_ms,
                           burst_count: burst_count,
                           messages_per_burst: messages_per_burst
                         } = scenario ->
      result = run_case(scenario)

      IO.puts(
        "=== spacing=#{spacing_ms}ms burst_count=#{burst_count} messages_per_burst=#{messages_per_burst} ==="
      )

      IO.puts("expected=#{burst_count * messages_per_burst}")
      IO.puts("received=#{result.received}")
      IO.puts("inversions=#{result.inversions}")
      IO.puts("elapsed_ms=#{result.elapsed_ms}")

      if result.inversions > 0 do
        IO.puts("ordering issue reproduced")
      else
        IO.puts("no inversion observed for this scenario")
      end

      IO.puts("")
    end)

    run_concurrent_flood(@concurrent_flood)
    IO.puts("")
    run_scheduler_stall_check(@scheduler_stall_check)
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
      Zenohex.Session.declare_publisher(publisher_session_id, "sensor/foo/observations", congestion_control: :block)

    try do
      Process.sleep(500)
      drain_mailbox()

      started_at = System.monotonic_time(:millisecond)
      publish_bursts(publisher_id, burst_count, messages_per_burst, spacing_ms)

      expected = burst_count * messages_per_burst
      received = collect_received(expected)
      elapsed_ms = System.monotonic_time(:millisecond) - started_at

      %{
        received: length(received),
        inversions: count_inversions(received),
        elapsed_ms: elapsed_ms
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

  defp drain_mailbox do
    receive do
      %Zenohex.Sample{} -> drain_mailbox()
    after
      0 -> :ok
    end
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

  # WHY: a single sequential publisher process can't outrun the forwarder
  #      (each `put` round-trips through Zenoh, naturally pacing production).
  #      Multiple concurrent publisher processes remove that pacing, which is
  #      needed to actually push the native queue past CHANNEL_CAPACITY (axis A).
  #      Order across producers is inherently non-deterministic here, so this
  #      checks for dropped sequence numbers instead of inversions.
  defp run_concurrent_flood(%{producers: producers, messages_per_producer: messages_per_producer}) do
    config =
      Zenohex.Config.default()
      |> config_with_scouting_delay(0)

    {:ok, subscriber_session_id} = Zenohex.Session.open(config)
    {:ok, publisher_session_id} = Zenohex.Session.open(config)

    {:ok, subscriber_id} =
      Zenohex.Session.declare_subscriber(subscriber_session_id, @key_expr, self())

    {:ok, publisher_id} =
      Zenohex.Session.declare_publisher(publisher_session_id, "sensor/foo/observations", congestion_control: :block)

    total = producers * messages_per_producer

    IO.puts(
      "=== concurrent flood: producers=#{producers} messages_per_producer=#{messages_per_producer} total=#{total} ==="
    )

    try do
      Process.sleep(500)
      drain_mailbox()

      started_at = System.monotonic_time(:millisecond)

      tasks =
        for producer_index <- 0..(producers - 1) do
          Task.async(fn ->
            for local_index <- 0..(messages_per_producer - 1) do
              seq = producer_index * messages_per_producer + local_index
              :ok = Zenohex.Publisher.put(publisher_id, ~s({"seq":#{seq}}))
            end
          end)
        end

      Task.await_many(tasks, :infinity)
      publish_elapsed_ms = System.monotonic_time(:millisecond) - started_at

      {received, last_received_at} = collect_until_quiet([], started_at)
      elapsed_ms = System.monotonic_time(:millisecond) - started_at
      drain_elapsed_ms = last_received_at - started_at

      expected_set = MapSet.new(0..(total - 1))
      received_set = MapSet.new(received)
      missing = MapSet.difference(expected_set, received_set)

      throughput_per_sec =
        if drain_elapsed_ms > 0, do: Float.round(length(received) * 1000 / drain_elapsed_ms, 1), else: 0.0

      IO.puts("publish_elapsed_ms=#{publish_elapsed_ms}")
      IO.puts("received=#{length(received)}")
      IO.puts("missing=#{MapSet.size(missing)}")
      IO.puts("drain_elapsed_ms=#{drain_elapsed_ms}")
      IO.puts("throughput_msgs_per_sec=#{throughput_per_sec}")
      IO.puts("elapsed_ms=#{elapsed_ms}")

      if MapSet.size(missing) > 0 do
        IO.puts("drop reproduced (some samples never arrived)")
      else
        IO.puts("no drop observed")
      end
    after
      _ = Zenohex.Subscriber.undeclare(subscriber_id)
      _ = Zenohex.Publisher.undeclare(publisher_id)
      _ = Zenohex.Session.close(subscriber_session_id)
      _ = Zenohex.Session.close(publisher_session_id)
    end
  end

  defp collect_until_quiet(acc, started_at, last_received_at \\ nil) do
    receive do
      %Zenohex.Sample{payload: payload} ->
        now = System.monotonic_time(:millisecond)

        case Jason.decode(payload) do
          {:ok, %{"seq" => seq}} -> collect_until_quiet([seq | acc], started_at, now)
          _ -> collect_until_quiet(acc, started_at, last_received_at)
        end
    after
      # WHY: long enough that Fifo's blocking-backpressure drain (slow but lossless)
      #      isn't mistaken for a true drop; short quiet windows previously cut off
      #      collection while messages were still in flight, inflating "missing".
      5_000 -> {acc, last_received_at || started_at}
    end
  end

  # WHY: `Zenohex.Publisher.put/2` is a regular (non-dirty) NIF that blocks
  #      synchronously on `.wait()`. Fifo's "block the producer when full"
  #      design means enough concurrent callers stuck on a full FifoChannel can
  #      tie up every regular BEAM scheduler at once, starving the whole node
  #      (not just this test) instead of just this test's own processes. Ring's
  #      producer never blocks, so it should not starve the scheduler this way,
  #      at the cost of dropping samples (see run_concurrent_flood).
  defp run_scheduler_stall_check(%{
         producers: producers,
         messages_per_producer: messages_per_producer,
         canary_interval_ms: canary_interval_ms
       }) do
    config =
      Zenohex.Config.default()
      |> config_with_scouting_delay(0)

    {:ok, subscriber_session_id} = Zenohex.Session.open(config)
    {:ok, publisher_session_id} = Zenohex.Session.open(config)

    {:ok, subscriber_id} =
      Zenohex.Session.declare_subscriber(subscriber_session_id, @key_expr, self())

    {:ok, publisher_id} =
      Zenohex.Session.declare_publisher(publisher_session_id, "sensor/foo/observations", congestion_control: :block)

    total = producers * messages_per_producer

    IO.puts(
      "=== scheduler stall check: schedulers_online=#{System.schedulers_online()} producers=#{producers} messages_per_producer=#{messages_per_producer} total=#{total} ==="
    )

    try do
      Process.sleep(500)
      drain_mailbox()

      canary = SchedulerCanary.start(canary_interval_ms)
      started_at = System.monotonic_time(:millisecond)

      tasks =
        for producer_index <- 0..(producers - 1) do
          Task.async(fn ->
            for local_index <- 0..(messages_per_producer - 1) do
              seq = producer_index * messages_per_producer + local_index
              :ok = Zenohex.Publisher.put(publisher_id, ~s({"seq":#{seq}}))
            end
          end)
        end

      Task.await_many(tasks, :infinity)
      publish_elapsed_ms = System.monotonic_time(:millisecond) - started_at

      {received, _last_received_at} = collect_until_quiet([], started_at)
      gaps = SchedulerCanary.stop(canary)

      expected_set = MapSet.new(0..(total - 1))
      received_set = MapSet.new(received)
      missing = MapSet.size(MapSet.difference(expected_set, received_set))

      max_gap = Enum.max(gaps, fn -> 0 end)
      stalls = Enum.count(gaps, &(&1 > canary_interval_ms * 5))

      IO.puts("publish_elapsed_ms=#{publish_elapsed_ms}")
      IO.puts("received=#{length(received)}")
      IO.puts("missing=#{missing}")
      IO.puts("canary_ticks=#{length(gaps)}")
      IO.puts("canary_max_gap_ms=#{max_gap} (expected ~#{canary_interval_ms})")
      IO.puts("canary_stalls(>#{canary_interval_ms * 5}ms)=#{stalls}")

      if max_gap > canary_interval_ms * 5 do
        IO.puts("scheduler stall observed (canary fell behind)")
      else
        IO.puts("no scheduler stall observed")
      end
    after
      _ = Zenohex.Subscriber.undeclare(subscriber_id)
      _ = Zenohex.Publisher.undeclare(publisher_id)
      _ = Zenohex.Session.close(subscriber_session_id)
      _ = Zenohex.Session.close(publisher_session_id)
    end
  end
end

SubscriberOrderRepro.run()
