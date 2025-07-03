defmodule Zenohex.Session do
  @moduledoc """
  Documentation #{__MODULE__}
  """

  @type put_opts :: [
          attachment: binary() | nil,
          congestion_control: :drop | :block,
          encoding: String.t(),
          express: boolean(),
          priority:
            :real_time
            | :interactive_high
            | :interactive_low
            | :data_high
            | :data
            | :data_low
            | :background
        ]

  @type delete_opts :: [
          attachment: binary() | nil,
          congestion_control: :drop | :block,
          express: boolean(),
          priority:
            :real_time
            | :interactive_high
            | :interactive_low
            | :data_high
            | :data
            | :data_low
            | :background
        ]

  @type get_opts :: [
          attachment: binary() | nil,
          congestion_control: :drop | :block,
          soncolidation: :auto | :none | :monotonic | :latest,
          encoding: String.t(),
          express: boolean(),
          payload: binary() | nil,
          priority:
            :real_time
            | :interactive_high
            | :interactive_low
            | :data_high
            | :data
            | :data_low
            | :background,
          target: :best_matching | :all | :all_complete
        ]

  @doc """
  Opens a session using Zenoh default config.

  Internally opens a session via `open/1`, using `Zenohex.Config.default/0`.
  """
  @spec open() :: {:ok, session_id :: Zenohex.Nif.id()} | {:error, reason :: term()}
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
  @spec open(String.t()) :: {:ok, session_id :: Zenohex.Nif.id()} | {:error, reason :: term()}
  defdelegate open(json5_binary), to: Zenohex.Nif, as: :session_open

  @doc """
  Closes a session.

  Releases all resources associated with the given `session_id`.
  After calling this function, the `session_id` must not be used again.

  ## Parameters

  - `session_id` : The session identifier returned by `open/1`.
  """
  @spec close(session_id :: Zenohex.Nif.id()) :: :ok | {:error, reason :: term()}
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
  @spec put(session_id :: Zenohex.Nif.id(), String.t(), binary(), put_opts()) ::
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
  @spec delete(session_id :: Zenohex.Nif.id(), String.t(), delete_opts()) ::
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
  """
  @spec get(session_id :: Zenohex.Nif.id(), String.t(), non_neg_integer(), get_opts()) ::
          {:ok, [Zenohex.Sample.t() | Zenohex.Query.ReplyError.t()]}
          | {:error, :timeout}
          | {:error, term()}
  defdelegate get(session_id, selector, timeout, opts \\ []),
    to: Zenohex.Nif,
    as: :session_get

  defdelegate declare_publisher(session_id, key_expr, opts \\ []),
    to: Zenohex.Nif,
    as: :session_declare_publisher

  defdelegate declare_subscriber(session_id, key_expr, pid \\ self()),
    to: Zenohex.Nif,
    as: :session_declare_subscriber

  defdelegate declare_queryable(session_id, key_expr, pid \\ self()),
    to: Zenohex.Nif,
    as: :session_declare_queryable
end
