defmodule Zenohex.NifTest do
  use ExUnit.Case

  alias Zenohex.Nif

  test "add/2" do
    assert Nif.add(1, 2) == 3
  end
end
