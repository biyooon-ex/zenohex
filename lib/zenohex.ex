defmodule Zenohex do
  @moduledoc """
  Zenohex is a thin Elixir wrapper around Zenoh, implemented using Rustler.

  - Zenoh:
    - https://zenoh.io/
    - https://github.com/eclipse-zenoh/zenoh
  - Rustler: https://github.com/rusterlium/rustler

  To learn how to use this library,
  check the example implementations in the following directory:

  - #{Zenohex.MixProject.project()[:source_url]}/tree/main/lib/zenohex/examples
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

  @doc """
  Scouts for routers or peers.

  This function discovers either `:peer` or `:router` nodes based on the given configuration.
  It blocks until a response is received or the timeout is reached.

  ## Parameters

    - `what`: Either `:peer` or `:router`, indicating what type of node to search for.
    - `config`: The Zenoh configuration used for the scout operation.
    - `timeout`: The maximum time to wait (in milliseconds) before giving up.

  ## Examples

      iex> config = Zenohex.Config.default()
      iex> {:ok, hellos} = Zenohex.scout(:peer, config, 1000)

  """
  @spec scout(Zenohex.Scouting.what(), Zenohex.Config.t(), non_neg_integer()) ::
          {:ok, [Zenohex.Scouting.Hello.t()]} | {:error, :timeout} | {:error, term()}
  defdelegate scout(what, config, timeout), to: Zenohex.Scouting, as: :scout
end
