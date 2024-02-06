defmodule Zenohex.KeyExpr do
  alias Zenohex.Nif

  @spec intersects?(String.t(), String.t()) :: boolean()
  def intersects?(l, r) when is_binary(l) and is_binary(r) do
    Nif.key_expr_intersects(l, r)
  end
end
