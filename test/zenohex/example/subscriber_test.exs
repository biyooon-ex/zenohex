defmodule Zenohex.Example.SubscriberTest do
  use ExUnit.Case

  setup do
    {:ok, session_id} =
      Zenohex.Config.default()
      |> Zenohex.Test.Support.TestHelper.scouting_delay(0)
      |> Zenohex.Session.open()

    %{session_id: session_id}
  end

  test "invoke callback correctly", context do
    me = self()

    {:ok, _pid} =
      start_supervised(
        {Zenohex.Example.Subscriber,
         [
           session_id: context.session_id,
           key_expr: "key/expr",
           callback: fn sample -> send(me, sample) end
         ]},
        restart: :temporary
      )

    :ok = Zenohex.put("key/expr", "payload")

    assert_receive %Zenohex.Sample{}
  end
end
