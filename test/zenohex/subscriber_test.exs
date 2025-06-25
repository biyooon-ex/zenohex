defmodule Zenohex.SubscriberTest do
  use ExUnit.Case

  setup do
    {:ok, session_id} =
      Zenohex.Config.default()
      |> Zenohex.Test.Support.TestHelper.scouting_delay(0)
      |> Zenohex.Session.open()

    {:ok, subscriber_id} = Zenohex.Session.declare_subscriber(session_id, "key/expr", self())

    %{
      session_id: session_id,
      subscriber_id: subscriber_id
    }
  end

  test "undeclare/1", context do
    assert :ok = Zenohex.Subscriber.undeclare(context.subscriber_id)
    # confirm already undeclare
    assert {:error, _} = Zenohex.Subscriber.undeclare(context.subscriber_id)
  end
end
