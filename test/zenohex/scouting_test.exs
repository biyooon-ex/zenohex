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
    # NOTE: If there are multiple interfaces, each interface replies hello.
    assert {:ok, hellos} =
             Zenohex.Scouting.scout(:peer, Zenohex.Config.default(), 100)

    assert %Zenohex.Scouting.Hello{} = List.first(hellos)
  end
end
