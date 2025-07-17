defmodule Zenohex.ScoutingTest do
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

  test "scout/3" do
    assert {:ok, [%Zenohex.Scouting.Hello{}]} =
             Zenohex.Scouting.scout(:peer, Zenohex.Config.default(), 100)
  end
end
