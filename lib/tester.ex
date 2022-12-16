defmodule Tester do
  @spec pub(charlist(), charlist()) :: no_return()
  def pub(keyexpr, value) do
    NifZenoh.tester_pub(keyexpr, value)
  end

  @spec sub(charlist()) :: no_return()
  def sub(keyexpr) do
    NifZenoh.tester_sub(keyexpr)
  end
end
