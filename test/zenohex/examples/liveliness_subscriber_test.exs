defmodule Zenohex.Examples.LivelinessSubscriberTest do
  use ExUnit.Case

  setup do
    {:ok, session_id} =
      Zenohex.Config.default()
      |> Zenohex.Test.Support.TestHelper.scouting_delay(0)
      |> Zenohex.Session.open()

    on_exit(fn -> Zenohex.Session.close(session_id) end)

    %{
      session_id: session_id,
      key_expr: "key/expr",
      me: self()
    }
  end

  test "exmaple works correctly", context do
    assert {:ok, _pid} =
             Zenohex.Examples.LivelinessSubscriber.start_link(
               session_id: context.session_id,
               key_expr: context.key_expr,
               callback: fn sample -> send(context.me, sample) end
             )

    {:ok, token} = Zenohex.Liveliness.declare_token(context.session_id, context.key_expr)

    assert_receive %Zenohex.Sample{kind: :put}

    :ok = Zenohex.Liveliness.undeclare_token(token)

    assert_receive %Zenohex.Sample{kind: :delete}

    assert :ok = Zenohex.Examples.LivelinessSubscriber.stop()
  end
end
