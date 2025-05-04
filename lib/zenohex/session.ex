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

  @spec get(id(), String.t(), non_neg_integer()) :: {:ok, Zenohex.Sample.t()} | {:error, term()}
  defdelegate get(session_id, key_expr, timeout),
    to: Zenohex.Nif,
    as: :session_get

  @spec declare_publisher(id(), String.t(), String.t()) :: :ok
  defdelegate declare_publisher(session_id, key_expr, encoding \\ @zenoh_default_encoding),
    to: Zenohex.Nif,
    as: :session_declare_publisher

  @spec declare_subscriber(id(), String.t(), pid()) :: :ok
  defdelegate declare_subscriber(session_id, key_expr, pid),
    to: Zenohex.Nif,
    as: :session_declare_subscriber

  @spec declare_queryable(id(), String.t(), pid()) :: :ok
  defdelegate declare_queryable(session_id, key_expr, pid),
    to: Zenohex.Nif,
    as: :session_declare_queryable
end
