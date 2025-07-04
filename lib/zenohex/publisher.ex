defmodule Zenohex.Publisher do
  @moduledoc """
  Interface for publishing data via native Zenoh publishers.

  This module provides functions to send data using a previously declared
  publisher and to undeclare it when no longer needed.

  Publisher IDs are obtained from `Zenohex.Session.declare_publisher/3`.
  """

  @type id :: reference()

  @doc """
  Sends a binary payload using the specified publisher.

  The `id` must be a valid publisher reference obtained from
  `Zenohex.Session.declare_publisher/3`.
  """
  @spec put(id(), binary()) :: :ok | {:error, reason :: term()}
  defdelegate put(id, payload), to: Zenohex.Nif, as: :publisher_put

  @doc """
  Undeclares the publisher identified by the given ID.

  This releases associated resources.
  """
  @spec undeclare(id()) :: :ok | {:error, reason :: term()}
  defdelegate undeclare(id), to: Zenohex.Nif, as: :publisher_undeclare
end
