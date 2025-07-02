defmodule Zenohex do
  @moduledoc """
  Documentation #{__MODULE__}
  """

  @doc """
  Publishes a payload to the specified `key_expr`.

  Internally opens a Zenoh session, performs the publish operation, and ensures
  the session is closed afterward.

  ## Parameters

  - `key_expr` (`String.t`): The key expression to publish to.
  - `payload` (`binary`): The binary payload to publish.
  - `opts` (`keyword`): Additional options. See `Zenohex.Session.put/4` for details.
  """

  @spec put(String.t(), binary(), keyword()) :: :ok | {:error, reason :: term()}
  def put(key_expr, payload, opts \\ []) do
    {:ok, session_id} = Zenohex.Session.open()

    try do
      Zenohex.Session.put(session_id, key_expr, payload, opts)
    after
      Zenohex.Session.close(session_id)
    end
  end

  @spec delete(String.t(), keyword()) :: :ok | {:error, reason :: term()}
  def delete(key_expr, opts \\ []) do
    {:ok, session_id} = Zenohex.Session.open()

    try do
      Zenohex.Session.delete(session_id, key_expr, opts)
    after
      Zenohex.Session.close(session_id)
    end
  end

  @doc """
  Query data with the given `selector`.

  Internally opens a Zenoh session, performs the query, and ensures the session is closed.

  ## Parameters

  - `selector` (`String.t`): The key expression or selector to query.
  - `timeout` (`non_neg_integer`): Timeout in milliseconds to wait for query replies.
  - `opts` (`keyword`): Additional options. See `Zenohex.Session.get/4` for details.
  """
  @spec get(String.t(), non_neg_integer(), keyword()) ::
          {:ok, [Zenohex.Sample.t() | Zenohex.Query.ReplyError.t()]}
          | {:error, :timeout}
          | {:error, term()}
  def get(selector, timeout, opts \\ []) do
    {:ok, session_id} = Zenohex.Session.open()

    try do
      Zenohex.Session.get(session_id, selector, timeout, opts)
    after
      Zenohex.Session.close(session_id)
    end
  end
end
