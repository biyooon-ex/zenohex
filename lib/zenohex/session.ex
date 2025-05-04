defmodule Zenohex.Session do
  @type id :: reference()

  @zenoh_default_encoding "zenoh/bytes"

  @spec open() :: {:ok, Zenohex.Session.id()} | {:error, reason :: term()}
  def open(), do: open(Zenohex.Config.default())

  @spec open(binary()) :: {:ok, Zenohex.Session.id()} | {:error, reason :: term()}
  defdelegate open(json5_binary), to: Zenohex.Nif, as: :session_open

  @spec close(id()) :: :ok
  defdelegate close(id), to: Zenohex.Nif, as: :session_close

  @spec put(id(), String.t(), String.t(), String.t()) :: :ok
  defdelegate put(session_id, key_expr, payload, encoding \\ @zenoh_default_encoding),
    to: Zenohex.Nif,
    as: :session_put

  @spec declare_publisher(id(), String.t(), String.t()) :: :ok
  defdelegate declare_publisher(session_id, key_expr, encoding \\ @zenoh_default_encoding),
    to: Zenohex.Nif,
    as: :session_declare_publisher
end
