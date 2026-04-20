defmodule Zenohex.KeyExprTest do
  use ExUnit.Case

  test "canonize/1" do
    assert {:ok, "key/expr/*/**"} == Zenohex.KeyExpr.canonize("key/expr/**/*")
    assert {:error, _} = Zenohex.KeyExpr.canonize("invalid/key/expr?")
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

  test "join/2" do
    assert {:ok, "key/expr/sub"} = Zenohex.KeyExpr.join("key/expr", "sub")
    assert {:error, _} = Zenohex.KeyExpr.join("invalid/key/expr?", "sub")
  end

  test "join/2 returns canonized key expression" do
    assert {:ok, "key/expr/*/**"} == Zenohex.KeyExpr.join("key/expr/**", "*")
  end
end
