defmodule Zenohex.ConfigTest do
  use ExUnit.Case

  alias Zenohex.Config

  test "default/0" do
    assert is_binary(Config.default())
  end

  test "from_json5/1" do
    json5_binary = File.read!("test/support/fixtures/DEFAULT_CONFIG.json5")

    assert {:ok, json_binary} = Config.from_json5(json5_binary)
    assert is_binary(json_binary)

    assert {:error, _reason} = Config.from_json5("")
  end
end
