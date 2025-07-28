defmodule Zenohex.Subscriber do
  @moduledoc """
  Interface for managing Zenoh subscribers via the native layer.

  This module provides functions to undeclare subscribers, which stops
  message receiving and releases associated native resources.

  Subscribers are created with `Zenohex.Session.declare_subscriber/4`.
  """

  @type id :: reference()

  @doc """
  Undeclares the subscriber identified by the given ID.

  Stops receiving messages and releases resources associated with the subscriber.
  """
  @spec undeclare(id()) :: :ok | {:error, reason :: term()}
  defdelegate undeclare(id), to: Zenohex.Nif, as: :subscriber_undeclare
end
