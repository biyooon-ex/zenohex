defmodule Zenohex.ScoutingTest do
  use ExUnit.Case

  setup do
    {:ok, session_id} =
      Zenohex.Config.default()
      |> Zenohex.Test.Support.TestHelper.scouting_delay(0)
      |> Zenohex.Session.open()

    on_exit(fn -> :ok = Zenohex.Session.close(session_id) end)

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

  test "scout/3 accepts multiple node types" do
    assert {:ok, hellos} =
             Zenohex.Scouting.scout([:peer, :router, :client], Zenohex.Config.default(), 100)

    assert is_list(hellos)
  end

  test "scout/3 rejects an empty matcher" do
    assert {:error, :invalid_what_matcher} =
             Zenohex.Scouting.scout([], Zenohex.Config.default(), 100)
  end

  test "declare_scout/3 accepts multiple node types" do
    assert {:ok, scout} =
             Zenohex.Scouting.declare_scout([:peer, :router, :client], Zenohex.Config.default())

    assert :ok = Zenohex.Scouting.stop_scout(scout)
  end
end
