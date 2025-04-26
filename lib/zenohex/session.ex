defmodule Zenohex.Session do
  @type id :: reference()

  @spec open() :: {:ok, Zenohex.Session.id()} | {:error, reason :: term()}
  def open(), do: open(Zenohex.Config.default())

  @spec open(binary()) :: {:ok, Zenohex.Session.id()} | {:error, reason :: term()}
  defdelegate open(json5_binary), to: Zenohex.Nif, as: :session_open

  @spec close(id()) :: :ok
  defdelegate close(id), to: Zenohex.Nif, as: :session_close
end
