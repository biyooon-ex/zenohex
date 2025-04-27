defmodule Zenohex.PublisherTest do
  use ExUnit.Case

  alias Zenohex.Publisher

  setup_all do
    {:ok, session_id} = Zenohex.Session.open()
    {:ok, publisher_id} = Zenohex.Session.declare_publisher(session_id, "key/expr")
    %{publisher_id: publisher_id}
  end

  test "put/2", context do
    assert :ok = Publisher.put(context.publisher_id, "payload")
  end
end
