defmodule EntityThreadScaling do
  @moduledoc """
  Reproduction script for the "native thread count scales with entity count"
  concern raised in PR #217 review. Uses only the public Zenohex API (no
  library changes): declares many subscribers and measures the OS thread
  count of the BEAM process before/after, using macOS's `ps -M`.
  """

  @entity_counts [0, 50, 100, 200, 500, 1_000, 2_000, 5_000, 10_000, 15_000, 20_000, 30_000, 50_000]

  def run do
    beam_pid = System.pid()

    IO.puts("beam os pid=#{beam_pid}")
    IO.puts("baseline threads=#{thread_count(beam_pid)}")
    IO.puts("")

    {:ok, config} = Zenohex.Config.default() |> Zenohex.Config.insert_json5("scouting/delay", "0")
    {:ok, session_id} = Zenohex.Session.open(config)

    try do
      {final_ids, _} =
        Enum.reduce(@entity_counts, {[], 0}, fn target_count, {subscriber_ids, previous_count} ->
          to_add = target_count - previous_count

          started_at = System.monotonic_time(:millisecond)

          new_ids =
            Enum.map(1..to_add//1, fn n ->
              key = "entity_thread_scaling/#{previous_count + n}"

              case Zenohex.Session.declare_subscriber(session_id, key, self()) do
                {:ok, subscriber_id} -> subscriber_id
                {:error, reason} -> throw({:declare_failed, previous_count + n, reason})
              end
            end)

          elapsed_ms = System.monotonic_time(:millisecond) - started_at
          all_ids = subscriber_ids ++ new_ids
          # Give the OS a brief moment to finish spawning the forwarder threads.
          Process.sleep(200)

          IO.puts(
            "entities=#{length(all_ids)} threads=#{thread_count(beam_pid)} declare_ms=#{elapsed_ms}"
          )

          {all_ids, target_count}
        end)

      Enum.each(final_ids, &Zenohex.Subscriber.undeclare/1)
      Process.sleep(200)
      IO.puts("")
      IO.puts("after undeclaring all: threads=#{thread_count(beam_pid)}")
    rescue
      error ->
        IO.puts("declare_subscriber raised: #{Exception.format(:error, error, __STACKTRACE__)}")
        IO.puts("threads at failure=#{thread_count(beam_pid)}")
    catch
      {:declare_failed, at_count, reason} ->
        IO.puts("declare_subscriber failed at entity ##{at_count}: #{inspect(reason)}")
        IO.puts("threads at failure=#{thread_count(beam_pid)}")
    end

    Zenohex.Session.close(session_id)
  end

  defp thread_count(pid) do
    {output, 0} = System.cmd("ps", ["-M", "-p", to_string(pid)])

    output
    |> String.split("\n", trim: true)
    # drop header line
    |> Enum.drop(1)
    |> length()
  end
end

EntityThreadScaling.run()
