defmodule Zenohex.Publisher do
  defdelegate put(id, payload), to: Zenohex.Nif, as: :publisher_put
  defdelegate undeclare(id), to: Zenohex.Nif, as: :publisher_undeclare
end
