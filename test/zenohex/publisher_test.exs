defmodule Zenohex.PublisherTest do
  use ExUnit.Case

  setup do
    {:ok, session_id} = Zenohex.Session.open()
    {:ok, publisher_id} = Zenohex.Session.declare_publisher(session_id, "key/expr")

    %{
      session_id: session_id,
      publisher_id: publisher_id
    }
  end

  test "put/2", context do
    assert :ok = Zenohex.Publisher.put(context.publisher_id, "payload")

    :ok = Zenohex.Session.close(context.session_id)
    assert {:error, _reason} = Zenohex.Publisher.put(context.publisher_id, "payload")
  end
end
