defmodule Zenohex.Querier do
  @moduledoc """
  Interface for reusable Zenoh queriers via the native layer.

  Querier IDs are obtained from `Zenohex.Session.declare_querier/3`.
  A querier can issue multiple `get/3` requests while reusing its declaration-time
  configuration.
  """

  @type id :: reference()

  @type get_opts :: [
          attachment: binary() | nil,
          encoding: String.t(),
          parameters: String.t(),
          payload: binary() | nil
        ]

  @doc """
  Executes a query using the specified querier.

  The positional `timeout` controls how long this function waits while collecting
  replies. Declaration-time `:query_timeout` configured on the querier sets the
  Zenoh query timeout.
  """
  @spec get(id(), non_neg_integer(), get_opts()) ::
          {:ok, [Zenohex.Sample.t() | Zenohex.Query.ReplyError.t()]}
          | {:error, :timeout}
          | {:error, reason :: term()}
  defdelegate get(id, timeout, opts \\ []), to: Zenohex.Nif, as: :querier_get

  @doc """
  Executes a query asynchronously using the specified querier.

  Each reply is sent as a message (`%Zenohex.Sample{}` or `%Zenohex.Query.ReplyError{}`)
  to `pid`. Unlike `get/3`, there is no way to know when all replies have been received;
  use an application-level protocol to determine when to stop waiting.
  """
  @spec get_async(id(), pid(), get_opts()) :: :ok | {:error, reason :: term()}
  defdelegate get_async(id, pid \\ self(), opts \\ []), to: Zenohex.Nif, as: :querier_get_async

  @doc """
  Undeclares the querier identified by the given ID.
  """
  @spec undeclare(id()) :: :ok | {:error, reason :: term()}
  defdelegate undeclare(id), to: Zenohex.Nif, as: :querier_undeclare
end
