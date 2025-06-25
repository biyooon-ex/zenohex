defmodule Zenohex.PublisherTest do
  use ExUnit.Case

  setup do
    {:ok, session_id} =
      Zenohex.Config.default()
      |> Zenohex.Test.Support.TestHelper.scouting_delay(0)
      |> Zenohex.Session.open()

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

  test "undeclare/1", context do
    assert :ok = Zenohex.Publisher.undeclare(context.publisher_id)
    # confirm already undeclare
    assert {:error, _} = Zenohex.Publisher.undeclare(context.publisher_id)
  end
end
