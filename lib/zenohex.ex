defmodule Zenohex do
  @spec session_open() :: {:ok, Zenohex.Session.id()} | {:error, reason :: term()}
  defdelegate session_open(), to: Zenohex.Nif

  @spec session_close(Zenohex.Session.id()) :: :ok
  defdelegate session_close(session_id), to: Zenohex.Nif
end
