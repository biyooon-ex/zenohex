defmodule Zenohex do
  @moduledoc """
  Documentation for `#{__MODULE__}`.
  """

  alias Zenohex.Nif
  alias Zenohex.Session
  alias Zenohex.Config
  alias Zenohex.Config.Scouting

  @doc ~S"""
  Open a zenoh Session.

  ## Examples

      iex> Zenohex.open()
  """
  @spec open(Config.t()) :: {:ok, Session.t()} | {:error, reason :: any()}
  def open(config \\ %Config{}) do
    if delay = System.get_env("SCOUTING_DELAY") do
      Nif.zenoh_open(%Config{scouting: %Scouting{delay: String.to_integer(delay)}})
    else
      Nif.zenoh_open(config)
    end
  end

  @doc ~S"""
  Open a zenoh Session.

  ## Examples

      iex> Zenohex.open!()
  """
  @spec open!(Config.t()) :: Session.t()
  def open!(config \\ %Config{}) do
    {:ok, session} = open(config)
    session
  end
end
