defmodule Zenohex.KeyExpr do
  @moduledoc """
  Provides utility functions for working with Zenoh key expressions (keyexpr).

  Key expressions in Zenoh define paths or patterns used to match resources.
  These utilities help manage their correctness and relationships.
  """

  @doc """
  Canonizes the `key_expr`.

  ## Examples

      iex> Zenohex.KeyExpr.canonize("key/expr/**/*")
      {:ok, "key/expr/*/**"}
  """
  @spec canonize(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  defdelegate canonize(key_expr),
    to: Zenohex.Nif,
    as: :keyexpr_autocanonize

  @doc """
  Validate the `key_expr`.
  """
  @spec valid?(String.t()) :: boolean()
  defdelegate valid?(key_expr),
    to: Zenohex.Nif,
    as: :keyexpr_valid?

  @doc """
  Returns true if the keyexprs intersect.

  There exists at least one key which is contained in both of the sets defined by `keyr_expr1` and `key_expr2`.
  """
  @spec intersects?(String.t(), String.t()) :: boolean()
  defdelegate intersects?(key_expr1, key_expr2),
    to: Zenohex.Nif,
    as: :keyexpr_intersects?

  @doc """
  Returns true if `key_expr1` includes `key_expr2`.

  The set defined by `key_expr1` contains every key belonging to the set defined by `key_expr2`.
  """
  @spec includes?(String.t(), String.t()) :: boolean()
  defdelegate includes?(key_expr1, key_expr2),
    to: Zenohex.Nif,
    as: :keyexpr_includes?

  @doc """
  Joins two key expressions, inserting a `/` between them.

  Returns the resulting key expression string, canonized.

  ## Examples

      iex> Zenohex.KeyExpr.join("key/expr", "sub")
      {:ok, "key/expr/sub"}
  """
  @spec join(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  defdelegate join(key_expr1, key_expr2),
    to: Zenohex.Nif,
    as: :keyexpr_join
end
