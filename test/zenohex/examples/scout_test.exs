defmodule Zenohex.Examples.ScoutTest do
  use ExUnit.Case

  setup do
    {:ok, session_id} =
      Zenohex.Config.default()
      |> Zenohex.Test.Support.TestHelper.scouting_delay(0)
      |> Zenohex.Session.open()

    on_exit(fn -> Zenohex.Session.close(session_id) end)

    %{me: self()}
  end

  test "example works correctly", context do
    assert {:ok, _pid} =
             Zenohex.Examples.Scout.start_link(
               what: :peer,
               callback: fn hello -> send(context.me, hello) end
             )

    assert_receive %Zenohex.Scouting.Hello{}

    assert :ok = Zenohex.Examples.Scout.stop()
  end
end
