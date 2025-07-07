defmodule Zenohex.Session do
  @moduledoc """
  Interface for managing Zenoh sessions and related operations.

  This module provides functions to open and close Zenoh sessions, publish
  and retrieve data, and declare publishers, subscribers, and queryables.

  Internally, all operations are forwarded to the native layer via NIFs.

  Typical usage starts with `open/0` or `open/1` to create a session,
  followed by operations such as `put/4`, `get/4`, or `declare_publisher/3`.

  ## Examples

      iex> {:ok, session_id} = Zenohex.Session.open()
      iex> Zenohex.Session.put(session_id, "key/expr", "payload")
      iex> Zenohex.Session.close(session_id)

  This module serves as the main entry point for using Zenoh in Elixir.
  """

  @type id :: reference()

  @type congestion_control :: :drop | :block

  @type priority ::
          :real_time
          | :interactive_high
          | :interactive_low
          | :data_high
          | :data
          | :data_low
          | :background

  @type put_opts :: [
          attachment: binary() | nil,
          congestion_control: congestion_control(),
          encoding: String.t(),
          express: boolean(),
          priority: priority(),
          timestamp: String.t()
        ]

  @type delete_opts :: [
          attachment: binary() | nil,
          congestion_control: congestion_control(),
          express: boolean(),
          priority: priority()
        ]

  @type get_opts :: [
          attachment: binary() | nil,
          congestion_control: congestion_control(),
          consolidation: :auto | :none | :monotonic | :latest,
          encoding: String.t(),
          express: boolean(),
          payload: binary() | nil,
          priority: priority(),
          target: :best_matching | :all | :all_complete
        ]

  @type publisher_opts :: [
          congestion_control: congestion_control(),
          encoding: String.t(),
          express: boolean(),
          priority: priority()
        ]

  @type subscriber_opts :: []

  @type queryable_opts :: [
          complete: boolean()
        ]

  @doc """
  Opens a session using Zenoh default config.

  Internally opens a session via `open/1`, using `Zenohex.Config.default/0`.
  """
  @spec open() :: {:ok, session_id :: id()} | {:error, reason :: term()}
  def open(), do: open(Zenohex.Config.default())

  @doc """
  Opens a session with the given JSON5 or JSON configuration.

  The configuration must be provided as a JSON5 string.
  JSON is also supported as a subset of JSON5.

  ## Parameters

  - `json5_binary` (`String.t`): A JSON5 string representing the Zenoh configuration.

  ## Examples

      iex> {:ok, session_id} =
      ...> File.read!("test/support/fixtures/DEFAULT_CONFIG.json5") |>
      ...> Zenohex.Session.open()
  """
  @spec open(String.t()) :: {:ok, session_id :: id()} | {:error, reason :: term()}
  defdelegate open(json5_binary), to: Zenohex.Nif, as: :session_open

  @doc """
  Closes a session.

  Releases all resources associated with the given `session_id`.
  After calling this function, the `session_id` must not be used again.

  ## Parameters

  - `session_id` : The session identifier returned by `open/1`.
  """
  @spec close(session_id :: id()) :: :ok | {:error, reason :: term()}
  defdelegate close(session_id), to: Zenohex.Nif, as: :session_close

  @doc """
  Publishes a payload to the given `key_expr` within an open session.

  This function sends a value (as a binary) to the specified key expression.

  ## Parameters

  - `session_id` : The session identifier returned by `open/0` or `open/1`.
  - `key_expr` : The key expression to publish to.
  - `payload` : The value to publish, as a binary.
  - `opts` : Options for the publish operation.

  ## Examples

      iex> {:ok, session_id} = Zenohex.Session.open()
      iex> Zenohex.Session.put(session_id, "key/expr", "payload")
      :ok
  """
  @spec put(session_id :: id(), String.t(), binary(), put_opts()) ::
          :ok | {:error, reason :: term()}
  defdelegate put(session_id, key_expr, payload, opts \\ []),
    to: Zenohex.Nif,
    as: :session_put

  @doc """
  Deletes data matching the given `key_expr`.

  ## Parameters

  - `session_id` : The session identifier returned by `open/0` or `open/1`.
  - `key_expr` : The key expression to delete.
  - `opts` : Options for the delete operation.

  ## Examples

      iex> {:ok, session_id} = Zenohex.Session.open()
      iex> Zenohex.Session.delete(session_id, "key/expr")
      :ok
  """
  @spec delete(session_id :: id(), String.t(), delete_opts()) ::
          :ok | {:error, reason :: term()}
  defdelegate delete(session_id, key_expr, opts \\ []),
    to: Zenohex.Nif,
    as: :session_delete

  @doc """
  Query data with the given `selector`.

  ## Parameters

  - `session_id` : The session identifier returned by `open/0` or `open/1`.
  - `selector` : The selector to query.
  - `timeout` : Timeout in milliseconds to wait for query replies.
  - `opts` : Options for the get operation.

  ## Examples

      iex> {:ok, session_id} = Zenohex.Session.open()
      iex> Zenohex.Session.get(session_id, "key/expr")
      {:ok, [%Zenohex.Sample{}]}
  """
  @spec get(session_id :: id(), String.t(), non_neg_integer(), get_opts()) ::
          {:ok, [Zenohex.Sample.t() | Zenohex.Query.ReplyError.t()]}
          | {:error, :timeout}
          | {:error, term()}
  defdelegate get(session_id, selector, timeout, opts \\ []),
    to: Zenohex.Nif,
    as: :session_get

  @doc """
  New zenoh timestamp string associated with the given session.

  ## Parameters

  - `session_id` : The session identifier returned by `open/0` or `open/1`.

  ## Examples

      iex> {:ok, session_id} = Zenohex.Session.open()
      iex> {:ok, zenoh_timestamp} = Zenohex.Session.new_timestamp(session_id)
      iex> [timestamp, zenoh_id_string] = String.split(zenoh_timestamp, "/")
      iex> {:ok, %DateTime{}, 0} = DateTime.from_iso8601(timestamp)
  """
  @spec new_timestamp(session_id :: id()) :: {:ok, String.t()} | {:error, term()}
  defdelegate new_timestamp(session_id),
    to: Zenohex.Nif,
    as: :session_new_timestamp

  @doc """
  Declares a publisher associated with the given session and `key_expr`.

  ## Parameters

    - `session_id`: Identifier of the session returned by `open/0` or `open/1`.
    - `key_expr`: Key expression to publish under.
    - `opts`: Options for configuring the publisher.
  """
  @spec declare_publisher(session_id :: id(), String.t(), keyword()) ::
          {:ok, publisher_id :: Zenohex.Publisher.id()} | {:error, reason :: term()}
  defdelegate declare_publisher(session_id, key_expr, opts \\ []),
    to: Zenohex.Nif,
    as: :session_declare_publisher

  @doc """
  Declares a subscriber for the specified `key_expr`.

  ## Parameters

    - `session_id`: Identifier of the session returned by `open/0` or `open/1`.
    - `key_expr`: Key expression to subscribe to.
    - `pid`: Process to receive subscription messages. Defaults to the calling process.
      - Messages are delivered as `Zenohex.Sample`.
    - `opts`: Options for configuring the subscriber.
  """
  @spec declare_subscriber(session_id :: id(), String.t(), pid(), subscriber_opts()) ::
          {:ok, subscriber_id :: Zenohex.Subscriber.id()}
  defdelegate declare_subscriber(session_id, key_expr, pid \\ self(), opts \\ []),
    to: Zenohex.Nif,
    as: :session_declare_subscriber

  @doc """
  Declares a queryable for the specified `key_expr`.

  ## Parameters

    - `session_id`: Identifier of the session returned by `open/0` or `open/1`.
    - `key_expr`: Key expression that the queryable will handle.
    - `pid`: Process to receive query messages. Defaults to the calling process.
       - Messages are delivered as `Zenohex.Query`
    - `opts`: Options for configuring the queryable.
  """
  @spec declare_queryable(session_id :: id(), String.t(), pid(), queryable_opts()) ::
          {:ok, queryable_id :: Zenohex.Queryable.id()}
  defdelegate declare_queryable(session_id, key_expr, pid \\ self(), opts \\ []),
    to: Zenohex.Nif,
    as: :session_declare_queryable
end
