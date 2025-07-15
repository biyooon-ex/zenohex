defmodule Zenohex.ConfigTest do
  use ExUnit.Case

  test "default/0" do
    assert is_binary(Zenohex.Config.default())
  end

  test "from_json5/1" do
    json5_binary = File.read!("test/support/fixtures/DEFAULT_CONFIG.json5")

    assert {:ok, json_binary} = Zenohex.Config.from_json5(json5_binary)
    assert is_binary(json_binary)

    assert {:error, _reason} = Zenohex.Config.from_json5("")
  end

  test "update_in/3" do
    config = Zenohex.Config.default()

    assert config =~ "scouting\":{\"delay\":null"

    config = Zenohex.Config.update_in(config, ["scouting", "delay"], fn _ -> 100 end)

    assert config =~ "scouting\":{\"delay\":100"
  end
end
