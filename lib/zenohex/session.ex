defmodule Zenohex.Session do
  @moduledoc """
  Documentation #{__MODULE__}
  """

  @type put_opts :: [
          congestion_control: :drop | :block,
          express: boolean(),
          encoding: String.t(),
          priority:
            :real_time
            | :interactive_high
            | :interactive_low
            | :data_high
            | :data
            | :data_low
            | :background
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

  - `session_id` (`Zenohex.Nif.id()`): The session identifier returned by `open/1`.
  """
  @spec close(session_id :: Zenohex.Nif.id()) :: :ok | {:error, reason :: term()}
  defdelegate close(session_id), to: Zenohex.Nif, as: :session_close

  @doc """
  Publishes a payload to the given `key_expr` within an open session.

  This function sends a value (as a binary) to the specified key expression.
  You must provide a valid session ID, which can be obtained using `open/0` or `open/1`.

  ## Parameters

  - `session_id` : The session identifier returned by `open/1`.
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
