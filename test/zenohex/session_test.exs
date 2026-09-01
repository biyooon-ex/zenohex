defmodule Zenohex.SessionTest do
  use ExUnit.Case

  setup do
    {:ok, session_id} =
      Zenohex.Config.default()
      |> Zenohex.Test.Support.TestHelper.scouting_delay(0)
      |> Zenohex.Session.open()

    # WHY: Windows CI can timeout flakily on close, so teardown close is not asserted.
    on_exit(fn ->
      case :os.type() do
        {:win32, _} -> _ = Zenohex.Session.close(session_id)
        _ -> :ok = Zenohex.Session.close(session_id)
      end
    end)

    %{session_id: session_id}
  end

  test "open/0" do
    assert {:ok, _session_id} = Zenohex.Session.open()
  end

  test "open/1" do
    assert {:ok, _session_id} =
             Zenohex.Config.default()
             |> Zenohex.Test.Support.TestHelper.scouting_delay(0)
             |> Zenohex.Session.open()
  end

  test "open/1 accepts map config" do
    assert {:ok, map_config} =
             Zenohex.ConfigMap.default()
             |> Zenohex.ConfigMap.insert("scouting/delay", 0)

    assert {:ok, _session_id} = Zenohex.Session.open(map_config)
  end

  test "open/1 rejects printable charlist in map config" do
    assert {:error, reason} = Zenohex.Session.open(%{mode: ~c"peer"})
    assert reason =~ "charlist is not supported"
  end

  test "close/1" do
    {:ok, session_id} = Zenohex.Session.open()
    refute Zenohex.Session.closed?(session_id)
    assert Zenohex.Session.close(session_id) == :ok
    assert Zenohex.Session.closed?(session_id)
    assert Zenohex.Session.close(session_id) == {:error, "session not found"}
  end

  test "fixed Zenoh ID sessions retain per-open identity" do
    config = ~s({ id: "2300000000000001", scouting: { delay: 0 } })
    parent = self()

    {owner, owner_ref} =
      spawn_monitor(fn ->
        {:ok, old_session_id} = Zenohex.Session.open(config)
        send(parent, {:old_session_open, self()})

        receive do
          :close_old_session -> :ok = Zenohex.Session.close(old_session_id)
        end

        send(parent, {:old_session_closed, self()})

        receive do
          :check_and_drop_old ->
            send(parent, {:old_session_info, Zenohex.Session.info(old_session_id)})
        end
      end)

    assert_receive {:old_session_open, ^owner}, 5_000
    assert {:ok, new_session_id} = Zenohex.Session.open(config)

    send(owner, :close_old_session)
    assert_receive {:old_session_closed, ^owner}, 5_000

    on_exit(fn ->
      unless Zenohex.Session.closed?(new_session_id) do
        :ok = Zenohex.Session.close(new_session_id)
      end
    end)

    send(owner, :check_and_drop_old)
    assert_receive {:old_session_info, {:error, "session not found"}}, 5_000
    assert_receive {:DOWN, ^owner_ref, :process, ^owner, :normal}, 5_000

    refute Zenohex.Session.closed?(new_session_id)

    assert {:ok, %Zenohex.Session.Info{zid: "2300000000000001"}} =
             Zenohex.Session.info(new_session_id)
  end

  test "old entity resources cannot resolve a reopened session" do
    config = ~s({ id: "2300000000000002", scouting: { delay: 0 } })
    parent = self()

    {owner, owner_ref} =
      spawn_monitor(fn ->
        {:ok, old_session_id} = Zenohex.Session.open(config)

        {:ok, old_publisher_id} =
          Zenohex.Session.declare_publisher(old_session_id, "issue/230/old")

        :ok = Zenohex.Session.close(old_session_id)
        :erlang.garbage_collect()
        send(parent, {:old_entity_ready, self()})

        receive do
          :check_old_entity ->
            send(parent, {:old_entity_result, Zenohex.Publisher.undeclare(old_publisher_id)})
        end
      end)

    assert_receive {:old_entity_ready, ^owner}, 5_000
    assert {:ok, new_session_id} = Zenohex.Session.open(config)

    assert {:ok, new_publisher_id} =
             Zenohex.Session.declare_publisher(new_session_id, "issue/230/new")

    on_exit(fn ->
      unless Zenohex.Session.closed?(new_session_id) do
        :ok = Zenohex.Session.close(new_session_id)
      end
    end)

    send(owner, :check_old_entity)
    assert_receive {:old_entity_result, {:error, "session not found"}}, 5_000
    assert_receive {:DOWN, ^owner_ref, :process, ^owner, :normal}, 5_000

    assert :ok = Zenohex.Publisher.put(new_publisher_id, "payload")
  end

  test "put/3", context do
    assert Zenohex.Session.put(context.session_id, "key/expr", "payload") == :ok
  end

  test "put/4 respects allowed_destination", context do
    {:ok, subscriber_id} =
      Zenohex.Session.declare_subscriber(context.session_id, "key/expr", self())

    on_exit(fn -> :ok = Zenohex.Subscriber.undeclare(subscriber_id) end)

    assert :ok =
             Zenohex.Session.put(context.session_id, "key/expr", "local",
               allowed_destination: :session_local
             )

    assert_receive %Zenohex.Sample{
      kind: :put,
      key_expr: "key/expr",
      payload: "local"
    }

    assert :ok =
             Zenohex.Session.put(context.session_id, "key/expr", "remote",
               allowed_destination: :remote
             )

    refute_receive %Zenohex.Sample{
      kind: :put,
      key_expr: "key/expr",
      payload: "remote"
    }
  end

  test "delete/2", context do
    assert Zenohex.Session.delete(context.session_id, "key/expr") == :ok
  end

  test "delete/3 respects allowed_destination", context do
    {:ok, subscriber_id} =
      Zenohex.Session.declare_subscriber(context.session_id, "key/expr", self())

    on_exit(fn -> :ok = Zenohex.Subscriber.undeclare(subscriber_id) end)

    assert :ok =
             Zenohex.Session.delete(context.session_id, "key/expr",
               allowed_destination: :session_local
             )

    assert_receive %Zenohex.Sample{
      kind: :delete,
      key_expr: "key/expr"
    }

    assert :ok =
             Zenohex.Session.delete(context.session_id, "key/expr", allowed_destination: :remote)

    refute_receive %Zenohex.Sample{
      kind: :delete,
      key_expr: "key/expr"
    }
  end

  test "delete/3 accepts timestamp", context do
    {:ok, subscriber_id} =
      Zenohex.Session.declare_subscriber(context.session_id, "key/expr", self())

    on_exit(fn -> :ok = Zenohex.Subscriber.undeclare(subscriber_id) end)

    {:ok, timestamp} = Zenohex.Session.new_timestamp(context.session_id)

    assert :ok =
             Zenohex.Session.delete(context.session_id, "key/expr", timestamp: timestamp)

    assert_receive %Zenohex.Sample{kind: :delete, key_expr: "key/expr", timestamp: ^timestamp}
  end

  test "get/3", context do
    assert {:error, _} = Zenohex.Session.get(context.session_id, "key/expr", 100)
  end

  test "new_timestamp/1", context do
    assert {:ok, zenoh_timestamp} = Zenohex.Session.new_timestamp(context.session_id)
    assert [timestamp, _zenoh_id_string] = String.split(zenoh_timestamp, "/")
    assert {:ok, %DateTime{}, 0} = DateTime.from_iso8601(timestamp)
  end

  test "info/1", context do
    assert {:ok, %Zenohex.Session.Info{}} = Zenohex.Session.info(context.session_id)
  end

  test "declare_publisher/2", context do
    assert {:ok, _publisher_id} =
             Zenohex.Session.declare_publisher(context.session_id, "key/expr")
  end

  test "declare_querier/2", context do
    assert {:ok, _querier_id} =
             Zenohex.Session.declare_querier(context.session_id, "key/expr")
  end
end
