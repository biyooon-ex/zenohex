defmodule Zenohex.Examples.SubscriberTest do
  use ExUnit.Case

  setup do
    {:ok, session_id} =
      Zenohex.Config.default()
      |> Zenohex.Test.Support.TestHelper.scouting_delay(0)
      |> Zenohex.Session.open()

    %{
      me: self(),
      session_id: session_id,
      key_expr: "key/expr"
    }
  end

  test "invoke callback correctly", context do
    {:ok, _pid} =
      Zenohex.Examples.Subscriber.start_link(
        session_id: context.session_id,
        key_expr: context.key_expr,
        callback: fn sample -> send(context.me, sample) end
      )

    :ok = Zenohex.put(context.key_expr, "payload")

    assert_receive %Zenohex.Sample{kind: :put, payload: "payload"}

    :ok = Zenohex.delete(context.key_expr)

    assert_receive %Zenohex.Sample{kind: :delete}

    assert :ok = Zenohex.Examples.Subscriber.stop()
  end
end
