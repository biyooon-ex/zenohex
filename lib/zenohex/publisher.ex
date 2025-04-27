defmodule Zenohex.Publisher do
  @type id :: reference()

  @spec put(id(), String.t()) :: :ok
  defdelegate put(id, payload), to: Zenohex.Nif, as: :publisher_put
end
