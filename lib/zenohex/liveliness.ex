defmodule Zenohex.Liveliness do
  @type token :: reference()

  @spec get(Zenohex.Session.id(), String.t(), non_neg_integer()) ::
          {:ok, [Zenohex.Sample.t() | Zenohex.Query.ReplyError.t()]}
          | {:error, :timeout}
          | {:error, term()}
  defdelegate get(session_id, key_expr, timeout), to: Zenohex.Nif, as: :liveliness_get

  @spec declare_subscriber(Zenohex.Session.id(), String.t(), pid(), keyword()) ::
          {:ok, subscriber_id :: Zenohex.Subscriber.id()}
  defdelegate declare_subscriber(session_id, key_expr, pid \\ self(), opts \\ []),
    to: Zenohex.Nif,
    as: :liveliness_declare_subscriber

  @spec undeclare_subscriber(Zenohex.Subscriber.id()) :: :ok | {:error, reason :: term()}
  defdelegate undeclare_subscriber(subscriber_id),
    to: Zenohex.Nif,
    as: :subscriber_undeclare

  @spec declare_token(Zenohex.Session.id(), String.t()) ::
          {:ok, token()} | {:error, term()}
  defdelegate declare_token(session_id, key_expr),
    to: Zenohex.Nif,
    as: :liveliness_declare_token

  @spec undeclare_token(token()) :: :ok | {:error, term()}
  defdelegate undeclare_token(token),
    to: Zenohex.Nif,
    as: :liveliness_token_undeclare
end
