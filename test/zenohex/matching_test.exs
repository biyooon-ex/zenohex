defmodule Zenohex.MatchingTest do
  use ExUnit.Case

  setup do
    {:ok, session_id} =
      Zenohex.Config.default()
      |> Zenohex.Test.Support.TestHelper.scouting_delay(0)
      |> Zenohex.Session.open()

    on_exit(fn -> Zenohex.Session.close(session_id) end)

    %{session_id: session_id}
  end

  test "status/1 returns matching for publisher", context do
    {:ok, subscriber_id} =
      Zenohex.Session.declare_subscriber(context.session_id, "key/expr", self())

    on_exit(fn ->
      # WHY: Explicitly undeclare `subscriber_id` after the assertion.
      #      Otherwise, the Elixir GC may release `subscriber_id` if it appears unused,
      #      which triggers Rust's `Drop` before matching status is observed.
      Zenohex.Subscriber.undeclare(subscriber_id)
    end)

    {:ok, publisher_id} = Zenohex.Session.declare_publisher(context.session_id, "key/expr")

    assert {:ok, true} = Zenohex.Matching.status(publisher_id)
  end

  test "status/1 returns matching for querier", context do
    {:ok, queryable_id} =
      Zenohex.Session.declare_queryable(context.session_id, "key/expr/**", self())

    on_exit(fn ->
      # WHY: Explicitly undeclare `queryable_id` after the assertion.
      #      Otherwise, the Elixir GC may release `queryable_id` if it appears unused,
      #      which triggers Rust's `Drop` before matching status is observed.
      Zenohex.Queryable.undeclare(queryable_id)
    end)

    {:ok, querier_id} = Zenohex.Session.declare_querier(context.session_id, "key/expr/**")

    assert {:ok, true} = Zenohex.Matching.status(querier_id)
  end

  test "declare_listener/2 receives matching updates for publisher", context do
    {:ok, publisher_id} = Zenohex.Session.declare_publisher(context.session_id, "key/expr")

    on_exit(fn ->
      # WHY: Explicitly undeclare `publisher_id`.
      #      Otherwise, the Elixir GC may release `publisher_id` if it appears unused,
      #      which triggers Rust's `Drop`, so matching status updates may no longer be received.
      Zenohex.Publisher.undeclare(publisher_id)
    end)

    {:ok, listener_id} = Zenohex.Matching.declare_listener(publisher_id, self())

    {:ok, subscriber_id} =
      Zenohex.Session.declare_subscriber(context.session_id, "key/expr", self())

    assert_receive %Zenohex.Matching.Status{matching: true}

    assert :ok = Zenohex.Subscriber.undeclare(subscriber_id)
    assert_receive %Zenohex.Matching.Status{matching: false}

    assert :ok = Zenohex.Matching.undeclare_listener(listener_id)
    assert {:error, _} = Zenohex.Matching.undeclare_listener(listener_id)
  end

  test "undeclare_listener/1 returns error after parent publisher undeclare", context do
    {:ok, publisher_id} = Zenohex.Session.declare_publisher(context.session_id, "key/expr")
    {:ok, listener_id} = Zenohex.Matching.declare_listener(publisher_id, self())

    # WHY: Parent publisher undeclare may already remove the matching listener on the Rust side.
    assert :ok = Zenohex.Publisher.undeclare(publisher_id)
    assert {:error, _} = Zenohex.Matching.undeclare_listener(listener_id)
  end
end
