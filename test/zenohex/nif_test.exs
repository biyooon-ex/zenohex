defmodule Zenohex.NifTest do
  use ExUnit.Case

  test "keyword_get_value/2 return correctly" do
    assert Zenohex.Nif.keyword_get_value([key: :value], :key) == :value
    assert Zenohex.Nif.keyword_get_value([], :key) == nil
    assert Zenohex.Nif.keyword_get_value([key: nil], :key) == nil
  end

  test "keyword_get_value/2 raise ArgumentError" do
    not_keyword = ""
    assert_raise ArgumentError, fn -> Zenohex.Nif.keyword_get_value(not_keyword, :key) end
  end
end
