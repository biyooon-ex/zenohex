defmodule Zenohex.KeyExprTest do
  use ExUnit.Case

  test "canonize/1" do
    assert Zenohex.KeyExpr.canonize("key/expr/**/*") == "key/expr/*/**"
    assert_raise ArgumentError, fn -> Zenohex.KeyExpr.canonize("invalid/key/expr?") end
  end

  test "valid?/1" do
    assert Zenohex.KeyExpr.valid?("key/expr")
    assert Zenohex.KeyExpr.valid?("key/expr/*/**")
    refute Zenohex.KeyExpr.valid?("invalid/key/expr?")
  end

  test "intersects?/2" do
    assert Zenohex.KeyExpr.intersects?("key/expr/**", "key/expr/1")

    assert_raise ArgumentError, fn ->
      Zenohex.KeyExpr.intersects?("valid/key/expr", "invalid/key/expr?")
    end
  end

  test "includes?/2" do
    assert Zenohex.KeyExpr.includes?("key/expr/**", "key/expr/1")

    assert_raise ArgumentError, fn ->
      Zenohex.KeyExpr.includes?("valid/key/expr", "invalid/key/expr?")
    end
  end
end
