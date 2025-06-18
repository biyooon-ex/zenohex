defmodule Zenohex.Queryable do
  defdelegate undeclare(id), to: Zenohex.Nif, as: :queryable_undeclare
end
