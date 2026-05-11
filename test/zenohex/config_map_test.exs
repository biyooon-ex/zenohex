defmodule Zenohex.ConfigMapTest do
  use ExUnit.Case

  test "default/0" do
    config = Zenohex.ConfigMap.default()

    assert is_map(config)
    assert Map.has_key?(config, "scouting")
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

    test "ConfigMap.from_env/0 when ZENOH_CONFIG is set" do
      System.put_env("ZENOH_CONFIG", "test/support/fixtures/DEFAULT_CONFIG.json5")
      assert {:ok, config} = Zenohex.ConfigMap.from_env()
      assert is_map(config)
    end

    test "ConfigMap.from_env/0 when ZENOH_CONFIG is not set" do
      System.delete_env("ZENOH_CONFIG")
      assert {:error, _reason} = Zenohex.ConfigMap.from_env()
    end
  end

  describe "map-centric API" do
    test "from_file/1 with valid file" do
      assert {:ok, config} =
               Zenohex.ConfigMap.from_file("test/support/fixtures/DEFAULT_CONFIG.json5")

      assert is_map(config)
    end

    test "from_file/1 with nonexistent file" do
      assert {:error, _reason} = Zenohex.ConfigMap.from_file("nonexistent.json5")
    end

    test "from_json5/1" do
      json5_binary = File.read!("test/support/fixtures/DEFAULT_CONFIG.json5")

      assert {:ok, config_map} = Zenohex.ConfigMap.from_json5(json5_binary)
      assert is_map(config_map)

      assert {:error, _reason} = Zenohex.ConfigMap.from_json5("")
    end

    test "get/2 with map config" do
      assert {:ok, config} =
               Zenohex.ConfigMap.from_file("test/support/fixtures/DEFAULT_CONFIG.json5")

      assert {:ok, 500} = Zenohex.ConfigMap.get(config, "scouting/delay")

      map = %{"scouting" => %{"delay" => 42}}
      assert {:ok, 42} = Zenohex.ConfigMap.get(map, "scouting/delay")
    end

    test "get/2 rejects binary config" do
      config = Zenohex.Config.default()

      assert {:error, {:config_must_be_map, ^config}} =
               Zenohex.ConfigMap.get(config, "scouting/delay")
    end

    test "get/2 returns nil when key exists with null value" do
      map = %{"mode" => nil, "scouting" => %{"delay" => nil}}

      assert {:ok, nil} = Zenohex.ConfigMap.get(map, "mode")
      assert {:ok, nil} = Zenohex.ConfigMap.get(map, "scouting/delay")
      assert {:error, :not_found} = Zenohex.ConfigMap.get(map, "scouting/timeout")
    end

    test "insert/3 with map config and key normalization" do
      map = %{mode: "peer", scouting: %{delay: 500}}

      assert {:ok, updated1} = Zenohex.ConfigMap.insert(map, "scouting/delay", 123)
      assert {:ok, 123} = Zenohex.ConfigMap.get(updated1, "scouting/delay")

      assert {:ok, updated2} =
               Zenohex.ConfigMap.insert(updated1, "connect/endpoints", ["tcp/localhost:7447"])

      assert {:ok, ["tcp/localhost:7447"]} = Zenohex.ConfigMap.get(updated2, "connect/endpoints")
    end

    test "insert/3 rejects binary config" do
      config = Zenohex.Config.default()

      assert {:error, {:config_must_be_map, ^config}} =
               Zenohex.ConfigMap.insert(config, "connect/endpoints", ["tcp/localhost:7447"])
    end

    test "insert/3 rejects printable charlist" do
      config = Zenohex.ConfigMap.default()

      assert {:error, reason} = Zenohex.ConfigMap.insert(config, "mode", ~c"peer")
      assert reason =~ "charlist is not supported"
    end

    test "merge/2 normalizes map keys" do
      map = %{mode: "peer", scouting: %{delay: 100}}

      assert {:ok, config} = Zenohex.ConfigMap.merge(%{}, map)
      assert is_map(config)
      assert {:ok, 100} = Zenohex.ConfigMap.get(config, "scouting/delay")
    end

    test "merge/2 deep merges map into config" do
      base = %{"mode" => "client", "scouting" => %{"delay" => 500, "other" => "value"}}

      assert {:ok, updated} =
               Zenohex.ConfigMap.merge(base, %{
                 mode: "peer",
                 scouting: %{delay: 100}
               })

      assert {:ok, "peer"} = Zenohex.ConfigMap.get(updated, "mode")
      assert {:ok, 100} = Zenohex.ConfigMap.get(updated, "scouting/delay")
      # deep merge: unrelated sub-key is preserved
      assert {:ok, "value"} = Zenohex.ConfigMap.get(updated, "scouting/other")
    end
  end

  describe "error handling" do
    test "merge/2 rejects unsupported value types" do
      # Test multiple unsupported types: PID, function, etc.
      unsupported_values = [self(), fn -> :ok end, make_ref()]

      Enum.each(unsupported_values, fn value ->
        map = %{mode: "peer", invalid: value}
        assert {:error, {:unsupported_value_type, _}} = Zenohex.ConfigMap.merge(%{}, map)
      end)
    end

    test "merge/2 rejects unsupported key types" do
      # Test multiple unsupported key types: integer, tuple
      unsupported_keys = [
        %{1 => "value"},
        %{{:a, :b} => "value"}
      ]

      Enum.each(unsupported_keys, fn map ->
        assert {:error, {:unsupported_key_type, _}} = Zenohex.ConfigMap.merge(%{}, map)
      end)
    end

    test "get/2 returns not_found when traversing through non-map values" do
      map = %{"mode" => "peer", "scouting" => %{"delay" => 500}, "a" => "scalar"}

      assert {:error, :not_found} = Zenohex.ConfigMap.get(map, "scouting/delay/invalid")
      assert {:error, :not_found} = Zenohex.ConfigMap.get(map, "a/b/c")
    end

    test "insert/3 with invalid path structure" do
      config = %{"a" => %{"b" => "scalar"}}

      # Try to put_in through a scalar value, should fail gracefully
      assert {:error, {:invalid_path, _}} = Zenohex.ConfigMap.insert(config, "a/b/c", "value")
    end

    test "merge/2 with empty list (edge case)" do
      map = %{items: []}

      assert {:ok, config} = Zenohex.ConfigMap.merge(%{}, map)
      assert {:ok, []} = Zenohex.ConfigMap.get(config, "items")
    end
  end
end
