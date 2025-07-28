defmodule Zenohex.SessionTest do
  use ExUnit.Case

  setup do
    {:ok, sessoin_id} =
      Zenohex.Config.default()
      |> Zenohex.Test.Support.TestHelper.scouting_delay(0)
      |> Zenohex.Session.open()

    on_exit(fn -> Zenohex.Session.close(sessoin_id) end)

    %{sessoin_id: sessoin_id}
  end

  test "open/0" do
    assert {:ok, _sessoin_id} = Zenohex.Session.open()
  end

  test "open/1" do
    assert {:ok, _sessoin_id} =
             Zenohex.Config.default()
             |> Zenohex.Test.Support.TestHelper.scouting_delay(0)
             |> Zenohex.Session.open()
  end

  test "close/0", context do
    assert Zenohex.Session.close(context.sessoin_id) == :ok
    assert Zenohex.Session.close(context.sessoin_id) == {:error, "session not found"}
  end

  test "put/3", context do
    assert Zenohex.Session.put(context.sessoin_id, "key/expr", "payload") == :ok
  end

  test "delete/2", context do
    assert Zenohex.Session.delete(context.sessoin_id, "key/expr") == :ok
  end

  test "get/3", context do
    assert {:error, _} = Zenohex.Session.get(context.sessoin_id, "key/expr", 100)
  end

  test "new_timestamp/1", context do
    assert {:ok, zenoh_timestamp} = Zenohex.Session.new_timestamp(context.sessoin_id)
    assert [timestamp, _zenoh_id_string] = String.split(zenoh_timestamp, "/")
    assert {:ok, %DateTime{}, 0} = DateTime.from_iso8601(timestamp)
  end

  test "info/1", context do
    assert {:ok, %Zenohex.Session.Info{}} = Zenohex.Session.info(context.sessoin_id)
  end

  test "declare_publisher/2", context do
    assert {:ok, _publisher_id} =
             Zenohex.Session.declare_publisher(context.sessoin_id, "key/expr")
  end
end
