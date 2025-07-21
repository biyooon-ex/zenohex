defmodule Zenohex.Liveliness do
  @moduledoc """
  A LivelinessToken is a token which liveliness is tied to the Zenoh Session
  and can be monitored by remote applications.

  see. https://docs.rs/zenoh/latest/zenoh/liveliness/index.html
  """

  @type token :: reference()

  @type get_opts :: [
          query_timeout: non_neg_integer()
        ]

  @doc """
  Query liveliness tokens with matching key expressions.

  ## Parameters

    - `key_expr` - The key expression matching liveliness tokens to query

  ## Examples

      iex> Zenohex.Liveliness.get(session_id, "key/expr", 100)
      {:ok, [%Zenohex.Sample{}]}
  """
  @spec get(Zenohex.Session.id(), String.t(), non_neg_integer(), get_opts()) ::
          {:ok, [Zenohex.Sample.t() | Zenohex.Query.ReplyError.t()]}
          | {:error, :timeout}
          | {:error, term()}
  defdelegate get(session_id, key_expr, timeout, opts \\ []), to: Zenohex.Nif, as: :liveliness_get

  @doc """
  Create a Subscriber for liveliness changes matching the given key expression.

  ## Parameters

    - `session_id` — The session to declare on
    - `key_expr` — Key expression to associate with
    - `pid` - Process to receive liveliness updates (defaults to `self()`)

  ## Examples

      iex> Zenohex.Liveliness.declare_subscriber(session_id, "key/expr")
      {:ok, #Reference<...>}
  """
  @spec declare_subscriber(Zenohex.Session.id(), String.t(), pid()) ::
          {:ok, subscriber_id :: Zenohex.Subscriber.id()}
  defdelegate declare_subscriber(session_id, key_expr, pid \\ self()),
    to: Zenohex.Nif,
    as: :liveliness_declare_subscriber

  @doc """
  Undeclare the Subscriber.

  ## Parameters

    - `subscriber_id` — The ID of the subscriber to undeclare

  ## Examples

      iex> Zenohex.Liveliness.undeclare_subscriber(subscriber_id)
      :ok
  """
  @spec undeclare_subscriber(Zenohex.Subscriber.id()) :: :ok | {:error, term()}
  defdelegate undeclare_subscriber(subscriber_id),
    to: Zenohex.Nif,
    as: :subscriber_undeclare

  @doc """
  Create a LivelinessToken for the given key expression.

  ## Parameters

    - `session_id` — The session to declare on
    - `key_expr` — Key expression to associate with

  ## Examples

      iex> Zenohex.Liveliness.declare_token(session_id, "key/expr")
      {:ok, #Reference<...>}
  """
  @spec declare_token(Zenohex.Session.id(), String.t()) ::
          {:ok, token()} | {:error, term()}
  defdelegate declare_token(session_id, key_expr),
    to: Zenohex.Nif,
    as: :liveliness_declare_token

  @doc """
  Undeclare the LivelinessToken.

  ## Examples

      iex> Zenohex.Liveliness.undeclare_token(token)
      :ok
  """
  @spec undeclare_token(token()) :: :ok | {:error, term()}
  defdelegate undeclare_token(token),
    to: Zenohex.Nif,
    as: :liveliness_token_undeclare
end
