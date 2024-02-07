defmodule Zenohex.Examples.PublisherTest do
  use ExUnit.Case

  alias Zenohex.Examples.PublisherServer

  setup do
    {:ok, session} = Zenohex.open()
    key_expr = "key/expression/pub"
    start_supervised!({PublisherServer, %{session: session, key_expr: key_expr}})
    :ok
  end

  test "put/1" do
    assert PublisherServer.put("put") == :ok
  end

  test "delete/0" do
    assert PublisherServer.delete() == :ok
  end

  test "congestion_control/1" do
    assert PublisherServer.congestion_control(:block) == :ok
    assert PublisherServer.put("put") == :ok
  end

  test "priority/1" do
    assert PublisherServer.priority(:real_time) == :ok
    assert PublisherServer.put("put") == :ok
  end
end
