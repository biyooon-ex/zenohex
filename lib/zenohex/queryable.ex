defmodule Zenohex.Queryable do
  @moduledoc """
  Interface for managing queryable entities in the Zenoh native layer.

  This module provides functions to undeclare a queryable,
  which stops handling incoming queries and releases associated resources.

  Queryables are declared via `Zenohex.Session.declare_queryable/4`.
  """

  @type id :: reference()

  @doc """
  Undeclares the queryable identified by the given ID.

  Stops handling incoming queries and releases associated resources.
  """
  @spec undeclare(id()) :: :ok | {:error, reason :: term()}
  defdelegate undeclare(id), to: Zenohex.Nif, as: :queryable_undeclare
end
