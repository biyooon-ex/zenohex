defmodule Zenohex.Query do
  @moduledoc """
  Represents an incoming Zenoh query and provides functions for replying to it.

  This module defines the structure used when receiving a query via a queryable,
  as well as functions for sending successful replies or error replies back to the sender.

  Queries are received as `%Zenohex.Query{}` structs in the process registered as a queryable.
  """

  @type zenoh_query :: reference()

  @type t :: %__MODULE__{
          attachment: binary() | nil,
          encoding: String.t() | nil,
          key_expr: String.t(),
          parameters: String.t(),
          payload: binary() | nil,
          selector: String.t(),
          zenoh_query: zenoh_query()
        }

  @type reply_opts :: [
          final?: boolean()
        ]

  defstruct [
    :attachment,
    :encoding,
    :key_expr,
    :parameters,
    :payload,
    :selector,
    :zenoh_query
  ]

  defmodule ReplyError do
    @zenoh_default_encoding "zenoh/bytes"

    @type t :: %__MODULE__{
            payload: binary(),
            encoding: String.t()
          }
    defstruct payload: "payload", encoding: @zenoh_default_encoding
  end

  @doc """
  Sends a reply to the given Zenoh query.

  This function is used inside a queryable process to respond to a query.
  The `key_expr` is the key the data is associated with, and the `payload`
  is the binary data to return.

  ## Options

    - `:final?` : Whether this is the final reply. Defaults to `true`.

  ## Examples

      iex> Zenohex.Query.reply(query.zenoh_query, "key/expr", "payload")
  """
  @spec reply(zenoh_query(), String.t(), binary(), reply_opts()) ::
          :ok | {:error, reason :: term()}
  defdelegate reply(zenoh_query, key_expr, payload, opts \\ [final?: true]),
    to: Zenohex.Nif,
    as: :query_reply

  @doc """
  Sends an error reply to the given Zenoh query.

  This can be used to signal failure or unsupported requests from within a queryable.

  ## Options

    - `:final?` : Whether this is the final reply. Defaults to `true`.

  ## Examples

      iex> Zenohex.Query.reply_error(query.zenoh_query, "unsupported query")
  """
  @spec reply_error(zenoh_query(), binary(), reply_opts()) ::
          :ok | {:error, reason :: term()}
  defdelegate reply_error(zenoh_query, payload, opts \\ [final?: true]),
    to: Zenohex.Nif,
    as: :query_reply_error

  @doc """
  Sends an delete reply to the given Zenoh query.

  ## Options

    - `:final?` : Whether this is the final reply. Defaults to `true`.

  ## Examples

      iex> Zenohex.Query.reply_delete(query.zenoh_query, "key/expr")
  """
  @spec reply_delete(zenoh_query(), String.t(), reply_opts()) ::
          :ok | {:error, reason :: term()}
  defdelegate reply_delete(zenoh_query, key_expr, opts \\ [final?: true]),
    to: Zenohex.Nif,
    as: :query_reply_delete
end
