defmodule Zenohex.Examples.PublisherTest do
  use ExUnit.Case

  setup do
    {:ok, session_id} =
      Zenohex.Config.default()
      |> Zenohex.Test.Support.TestHelper.scouting_delay(0)
      |> Zenohex.Session.open()

    on_exit(fn -> Zenohex.Session.close(session_id) end)

    key_expr = "key/expr"

    %{me: self(), session_id: session_id, key_expr: key_expr}
  end

  test "example works correctly", context do
    {:ok, _pid} =
      start_supervised(
        {Zenohex.Examples.Subscriber,
         [
           session_id: context.session_id,
           key_expr: context.key_expr,
           callback: fn sample -> send(context.me, sample) end
         ]},
        restart: :temporary
      )

    assert {:ok, _pid} =
             Zenohex.Examples.Publisher.start_link(
               session_id: context.session_id,
               key_expr: context.key_expr
             )

    assert :ok = Zenohex.Examples.Publisher.put("payload")

    assert_receive %Zenohex.Sample{kind: :put, payload: "payload"}

    assert :ok = Zenohex.Examples.Publisher.delete()

    assert_receive %Zenohex.Sample{kind: :delete}

    assert :ok = Zenohex.Examples.Publisher.stop()
  end
end
