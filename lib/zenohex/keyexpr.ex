defmodule Zenohex.KeyExpr do
  @moduledoc """
  Documentation for `#{__MODULE__}`.
  """

  alias Zenohex.Nif

  @doc ~S"""
  Returns true if the keyexprs intersect.  
  i.e. there exists at least one key which is contained in both of the sets defined by key_expr1 and key_expr2.
  """
  @spec intersects?(String.t(), String.t()) :: boolean()
  def intersects?(key_expr1, key_expr2) when is_binary(key_expr1) and is_binary(key_expr2) do
    Nif.key_expr_intersects(key_expr1, key_expr2)
  end
end
