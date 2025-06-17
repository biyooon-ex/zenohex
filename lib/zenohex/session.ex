defmodule Zenohex.Session do
  @zenoh_default_encoding "zenoh/bytes"

  def open(), do: open(Zenohex.Config.default())

  def open!(), do: open() |> then(fn {:ok, session_id} -> session_id end)

  defdelegate open(json5_binary), to: Zenohex.Nif, as: :session_open

  defdelegate close(id), to: Zenohex.Nif, as: :session_close

  def put(key_expr, payload), do: put(open!(), key_expr, payload)

  defdelegate put(session_id, key_expr, payload, encoding \\ @zenoh_default_encoding),
    to: Zenohex.Nif,
    as: :session_put

  def get(key_expr, timeout), do: get(open!(), key_expr, timeout)

  defdelegate get(session_id, selector, timeout),
    to: Zenohex.Nif,
    as: :session_get

  defdelegate declare_publisher(session_id, key_expr, encoding \\ @zenoh_default_encoding),
    to: Zenohex.Nif,
    as: :session_declare_publisher

  defdelegate declare_subscriber(session_id, key_expr, pid),
    to: Zenohex.Nif,
    as: :session_declare_subscriber

  defdelegate declare_queryable(session_id, key_expr, pid),
    to: Zenohex.Nif,
    as: :session_declare_queryable
end
