defmodule Zenohex.Session do
  def open(), do: open(Zenohex.Config.default())

  def open!(), do: open() |> then(fn {:ok, session_id} -> session_id end)

  defdelegate open(json5_binary), to: Zenohex.Nif, as: :session_open

  defdelegate close(id), to: Zenohex.Nif, as: :session_close

  defdelegate put(session_id, key_expr, payload, opts \\ []),
    to: Zenohex.Nif,
    as: :session_put

  defdelegate get(session_id, selector, timeout),
    to: Zenohex.Nif,
    as: :session_get

  defdelegate declare_publisher(session_id, key_expr, opts \\ []),
    to: Zenohex.Nif,
    as: :session_declare_publisher

  defdelegate declare_subscriber(session_id, key_expr, pid),
    to: Zenohex.Nif,
    as: :session_declare_subscriber

  defdelegate declare_queryable(session_id, key_expr, pid),
    to: Zenohex.Nif,
    as: :session_declare_queryable
end
