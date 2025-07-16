defmodule Zenohex.KeyexprTest do
  use ExUnit.Case

  test "canonize/1" do
    assert Zenohex.Keyexpr.canonize("key/expr/**/*") == "key/expr/*/**"
    assert_raise ArgumentError, fn -> Zenohex.Keyexpr.canonize("invalid/key/expr?") end
  end

  test "valid?/1" do
    assert Zenohex.Keyexpr.valid?("key/expr")
    assert Zenohex.Keyexpr.valid?("key/expr/*/**")
    refute Zenohex.Keyexpr.valid?("invalid/key/expr?")
  end

  test "intersects?/2" do
    assert Zenohex.Keyexpr.intersects?("key/expr/**", "key/expr/1")

    assert_raise ArgumentError, fn ->
      Zenohex.Keyexpr.intersects?("valid/key/expr", "invalid/key/expr?")
    end
  end

  test "includes?/2" do
    assert Zenohex.Keyexpr.includes?("key/expr/**", "key/expr/1")

    assert_raise ArgumentError, fn ->
      Zenohex.Keyexpr.includes?("valid/key/expr", "invalid/key/expr?")
    end
  end
end
