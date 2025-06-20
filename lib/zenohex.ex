defmodule Zenohex do
  def put(key_expr, payload) do
    session_id = Zenohex.Session.open!()

    try do
      Zenohex.Session.put(session_id, key_expr, payload)
    after
      Zenohex.Session.close(session_id)
    end
  end

  def get(selector, timeout) do
    session_id = Zenohex.Session.open!()

    try do
      Zenohex.Session.get(session_id, selector, timeout)
    after
      Zenohex.Session.close(session_id)
    end
  end
end
