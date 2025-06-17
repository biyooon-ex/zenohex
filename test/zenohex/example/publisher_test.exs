defmodule Zenohex.Example.PublisherTest do
  use ExUnit.Case

  test "put correctly" do
    me = self()

    {:ok, _pid} =
      start_supervised(
        {Zenohex.Example.Subscriber,
         [key_expr: "key/expr", callback: fn sample -> send(me, sample) end]},
        restart: :temporary
      )

    {:ok, _pid} =
      start_supervised({Zenohex.Example.Publisher, [key_expr: "key/expr"]}, restart: :temporary)

    :ok = Zenohex.Example.Publisher.put("payload")

    assert_receive %Zenohex.Sample{}
  end
end
