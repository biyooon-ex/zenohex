defmodule Zenohex do
  @moduledoc """
  Documentation for `Zenohex`.
  """

  @doc """

  """
  @spec open :: NifZenoh.session()
  def open do
    NifZenoh.zenoh_open()
  end
end
