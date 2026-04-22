defmodule Zenohex.ConfigTest do
  use ExUnit.Case

  test "default/0" do
    assert is_binary(Zenohex.Config.default())
  end

  describe "operation for ZENOH_CONFIG" do
    setup do
      previous_zenoh_config = System.get_env("ZENOH_CONFIG")

      on_exit(fn ->
        if previous_zenoh_config == nil do
          System.delete_env("ZENOH_CONFIG")
        else
          System.put_env("ZENOH_CONFIG", previous_zenoh_config)
        end
      end)
    end

    test "from_env/0 when ZENOH_CONFIG is set" do
      System.put_env("ZENOH_CONFIG", "test/support/fixtures/DEFAULT_CONFIG.json5")
      assert {:ok, config} = Zenohex.Config.from_env()
      assert is_binary(config)
    end

    test "from_env/0 when ZENOH_CONFIG is not set" do
      System.delete_env("ZENOH_CONFIG")
      assert {:error, _reason} = Zenohex.Config.from_env()
    end
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
    assert {:ok, "100"} = Zenohex.Config.get_json(updated, "scouting/delay")

    assert {:ok, updated1} = Zenohex.Config.insert_json5(updated, "mode", "\"peer\"")
    assert {:ok, "\"peer\""} = Zenohex.Config.get_json(updated1, "mode")

    assert {:ok, updated2} = Zenohex.Config.insert_json5(updated, "mode", "client")
    assert {:ok, "\"client\""} = Zenohex.Config.get_json(updated2, "mode")

    assert {:ok, updated3} =
             Zenohex.Config.insert_json5(updated2, "connect/endpoints", ["tcp/localhost:7447"])

    assert {:ok, "[\"tcp/localhost:7447\"]"} =
             Zenohex.Config.get_json(updated3, "connect/endpoints")

    assert {:error, reason} = Zenohex.Config.insert_json5(updated3, "mode", ~c"client")
    assert reason =~ "charlist is not supported"

    assert {:error, {:json_encode_failed, {kind, reason}}} =
             Zenohex.Config.insert_json5(updated3, "connect/endpoints", [self()])

    assert kind == :error
    refute is_nil(reason)

    assert {:ok, updated4} = Zenohex.Config.insert_json5(updated, "connect/endpoints", [])
    assert {:ok, "[]"} = Zenohex.Config.get_json(updated4, "connect/endpoints")
  end
end
