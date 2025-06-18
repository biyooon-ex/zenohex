defmodule Zenohex do
  def put(key_expr, payload) do
    session_id = Zenohex.Session.open!()

    try do
      Zenohex.Session.put(session_id, key_expr, payload)
    after
      Zenohex.Session.close(session_id)
    end
  end

  def get(key_expr, timeout) do
    session_id = Zenohex.Session.open!()

    try do
      Zenohex.Session.get(session_id, key_expr, timeout)
    after
      Zenohex.Session.close(session_id)
    end
  end
end
