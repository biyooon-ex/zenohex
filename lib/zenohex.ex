defmodule Zenohex do
  @moduledoc """
  Documentation for `Zenohex`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Zenohex.hello()
      :world

  """
  @spec open :: reference()
  def open do
    NifZenoh.zenoh_open()
  end
end
