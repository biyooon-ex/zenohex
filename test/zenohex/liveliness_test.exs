defmodule Zenohex.LivelinessTest do
  use ExUnit.Case

  setup do
    {:ok, session_id} =
      Zenohex.Config.default()
      |> Zenohex.Test.Support.TestHelper.scouting_delay(0)
      |> Zenohex.Session.open()

    on_exit(fn -> Zenohex.Session.close(session_id) end)

    %{
      session_id: session_id
    }
  end

  test "declare_subscriber/3", context do
    assert {:ok, _subscriber_id} =
             Zenohex.Liveliness.declare_subscriber(context.session_id, "key/expr", self())
  end

  test "undeclare_subscriber/1", context do
    {:ok, subscriber_id} =
      Zenohex.Liveliness.declare_subscriber(context.session_id, "key/expr", self())

    assert :ok = Zenohex.Liveliness.undeclare_subscriber(subscriber_id)

    # confirm already undeclared
    assert {:error, _} = Zenohex.Liveliness.undeclare_subscriber(subscriber_id)
  end

  test "declare_token/2", context do
    {:ok, _subscriber_id} =
      Zenohex.Liveliness.declare_subscriber(context.session_id, "key/expr", self())

    assert {:ok, _token} = Zenohex.Liveliness.declare_token(context.session_id, "key/expr")

    assert_receive %Zenohex.Sample{kind: :put}
  end

  test "undeclare_token/2", context do
    {:ok, _subscriber_id} =
      Zenohex.Liveliness.declare_subscriber(context.session_id, "key/expr", self())

    {:ok, token} = Zenohex.Liveliness.declare_token(context.session_id, "key/expr")

    assert_receive %Zenohex.Sample{kind: :put}

    assert :ok = Zenohex.Liveliness.undeclare_token(token)

    assert_receive %Zenohex.Sample{kind: :delete}

    # confirm already undeclared
    assert {:error, _} = Zenohex.Liveliness.undeclare_token(token)
  end

  test "get/3", context do
    {:ok, _token} = Zenohex.Liveliness.declare_token(context.session_id, "key/expr")

    assert {:ok, [%Zenohex.Sample{kind: :put}]} =
             Zenohex.Liveliness.get(context.session_id, "key/expr", 100)
  end
end
