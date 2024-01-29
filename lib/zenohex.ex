defmodule Zenohex do
  @moduledoc """
  Documentation for `#{__MODULE__}`.
  """

  alias Zenohex.Nif
  alias Zenohex.Session

  @doc ~S"""
  Open a zenoh Session.

  ## Examples

      iex> Zenohex.open!()
  """
  @spec open! :: Session.t()
  def open!() do
    Nif.zenoh_open()
  end
end
