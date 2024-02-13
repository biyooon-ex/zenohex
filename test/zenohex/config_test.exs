defmodule Zenohex.ConfigTest do
  use ExUnit.Case

  alias Zenohex.Config
  alias Zenohex.Config.Connect
  alias Zenohex.Config.Scouting

  test "" do
    config = %Config{
      connect: %Connect{endpoints: ["tcp/localhost:7447"]},
      scouting: %Scouting{delay: 200}
    }

    assert {:ok, _session} = Zenohex.open(config)
  end
end
