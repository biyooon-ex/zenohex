defmodule Zenohex do
  @moduledoc """
  Documentation for `#{__MODULE__}`.
  """

  alias Zenohex.Nif
  alias Zenohex.Session

  @doc ~S"""
  Open a zenoh Session.

  ## Examples

      iex> Zenohex.open()
  """
  @spec open :: {:ok, Session.t()} | {:error, reason :: any()}
  def open() do
    if System.get_env("SCOUTING_DELAY") == "0" do
      Nif.zenoh_scouting_delay_zero_session()
    else
      Nif.zenoh_open()
    end
  end
end
