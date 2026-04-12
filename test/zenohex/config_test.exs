defmodule Zenohex.ConfigTest do
  use ExUnit.Case

  test "default/0" do
    assert is_binary(Zenohex.Config.default())
  end

  test "from_env/0 when ZENOH_CONFIG is set" do
    System.put_env("ZENOH_CONFIG", "test/support/fixtures/DEFAULT_CONFIG.json5")
    assert {:ok, config} = Zenohex.Config.from_env()
    assert is_binary(config)
    on_exit(fn -> System.delete_env("ZENOH_CONFIG") end)
  end

  test "from_env/0 when ZENOH_CONFIG is not set" do
    System.delete_env("ZENOH_CONFIG")
    assert {:error, _reason} = Zenohex.Config.from_env()
  end

  test "from_file/1 with valid file" do
    assert {:ok, config} =
             Zenohex.Config.from_file("test/support/fixtures/DEFAULT_CONFIG.json5")

    assert is_binary(config)
  end

  test "from_file/1 with nonexistent file" do
    assert {:error, _reason} = Zenohex.Config.from_file("nonexistent.json5")
  end

  test "from_json5/1" do
    json5_binary = File.read!("test/support/fixtures/DEFAULT_CONFIG.json5")

    assert {:ok, json_binary} = Zenohex.Config.from_json5(json5_binary)
    assert is_binary(json_binary)

    assert {:error, _reason} = Zenohex.Config.from_json5("")
  end

  test "get_json/2" do
    assert {:ok, config} =
             Zenohex.Config.from_file("test/support/fixtures/DEFAULT_CONFIG.json5")

    assert {:ok, value} = Zenohex.Config.get_json(config, "scouting/delay")
    assert value == "500"
    assert is_binary(value)
  end

  test "get_json/2 with invalid key" do
    config = Zenohex.Config.default()
    assert {:error, _reason} = Zenohex.Config.get_json(config, "nonexistent/key/path")
  end

  test "insert_json5/3" do
    config = Zenohex.Config.default()

    assert {:ok, updated} = Zenohex.Config.insert_json5(config, "scouting/delay", "100")
    assert is_binary(updated)
    assert {:ok, "100"} = Zenohex.Config.get_json(updated, "scouting/delay")
  end

  test "update_in/3" do
    config = Zenohex.Config.default()

    assert config =~ "scouting\":{\"delay\":null"

    config = Zenohex.Config.update_in(config, ["scouting", "delay"], fn _ -> 100 end)

    assert config =~ "scouting\":{\"delay\":100"
  end
end
