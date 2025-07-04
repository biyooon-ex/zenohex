defmodule Zenohex do
  @moduledoc """
  Documentation #{__MODULE__}
  """

  @doc """
  Publishes a `payload` to the specified `key_expr`.

  Internally opens a session, performs the publish, and ensures the session is closed.

  ## Parameters

  - `key_expr` : The key expression to publish to.
  - `payload` : The binary payload to publish.
  - `opts` : Additional options. See `Zenohex.Session.put/4` for details.
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

  @doc """
  Deletes data matching the given `key_expr`.

  Internally opens a session, deletes the data, and ensures the session is closed.

  ## Parameters

  - `key_expr` : The key expression to delete.
  - `opts` : Additional options. See `Zenohex.Session.delete/3` for details.
  """
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

  Internally opens a session, performs the query, and ensures the session is closed.

  ## Parameters

  - `selector` : The selector to query.
  - `timeout` : Timeout in milliseconds to wait for query replies.
  - `opts` : Additional options. See `Zenohex.Session.get/4` for details.
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
