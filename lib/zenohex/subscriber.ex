defmodule Zenohex.Subscriber do
  defdelegate undeclare(id), to: Zenohex.Nif, as: :subscriber_undeclare
end
