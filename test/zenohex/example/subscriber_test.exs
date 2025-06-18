defmodule Zenohex.Example.SubscriberTest do
  use ExUnit.Case

  test "invoke callback correctly" do
    me = self()

    {:ok, _pid} =
      start_supervised(
        {Zenohex.Example.Subscriber,
         [key_expr: "key/expr", callback: fn sample -> send(me, sample) end]},
        restart: :temporary
      )

    :ok = Zenohex.put("key/expr", "payload")

    assert_receive %Zenohex.Sample{}
  end
end
