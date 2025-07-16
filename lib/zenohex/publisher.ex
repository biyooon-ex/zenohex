defmodule Zenohex.Publisher do
  @moduledoc """
  Interface for publishing data via native Zenoh publishers.

  This module provides functions to send data using a previously declared
  publisher and to undeclare it when no longer needed.

  Publisher IDs are obtained from `Zenohex.Session.declare_publisher/3`.
  """

  @type id :: reference()
  @type put_opts :: [
          attachment: binary() | nil,
          encoding: String.t(),
          timestamp: String.t()
        ]
  @type delete_opts :: [
          attachment: binary() | nil,
          timestamp: String.t()
        ]

  @doc """
  Sends a `kind: :put` sample with binary payload using the specified publisher.
  """
  @spec put(id(), binary(), put_opts()) :: :ok | {:error, reason :: term()}
  defdelegate put(id, payload, opts \\ []), to: Zenohex.Nif, as: :publisher_put

  @doc """
  Sends a `kind: :delete` sample using the specified publisher.
  """
  @spec delete(id(), delete_opts()) :: :ok | {:error, reason :: term()}
  defdelegate delete(id, opts \\ []), to: Zenohex.Nif, as: :publisher_delete

  @doc """
  Undeclares the publisher identified by the given ID.
  """
  @spec undeclare(id()) :: :ok | {:error, reason :: term()}
  defdelegate undeclare(id), to: Zenohex.Nif, as: :publisher_undeclare
end
