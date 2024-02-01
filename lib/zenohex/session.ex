defmodule Zenohex.Session do
  @moduledoc """
  Documentation for `#{__MODULE__}`.
  """

  alias Zenohex.Nif
  alias Zenohex.Publisher
  alias Zenohex.Subscriber
  alias Zenohex.PullSubscriber
  alias Zenohex.Queryable
  alias Zenohex.Query

  @type t :: reference()
  @type receiver :: reference()

  @doc ~S"""
  Create a Publisher for the given key expression.

  ## Examples

      iex> {:ok, session} = Zenohex.open()
      iex> Zenohex.Session.declare_publisher(session, "key/expression")
  """
  @spec declare_publisher(t(), String.t(), Publisher.Options.t()) ::
          {:ok, Publisher.t()} | {:error, reason :: String.t()}
  def declare_publisher(session, key_expr, opts \\ %Publisher.Options{})
      when is_reference(session) and is_binary(key_expr) and is_struct(opts, Publisher.Options) do
    Nif.declare_publisher(session, key_expr, opts)
  end

  @doc ~S"""
  Create a Subscriber for the given key expression.

  ## Examples

      iex> {:ok, session} = Zenohex.open()
      iex> Zenohex.Session.declare_subscriber(session, "key/expression")
  """
  @spec declare_subscriber(t(), String.t(), Subscriber.Options.t()) ::
          {:ok, Subscriber.t()} | {:error, reason :: String.t()}
  def declare_subscriber(session, key_expr, opts \\ %Subscriber.Options{})
      when is_reference(session) and is_binary(key_expr) and is_struct(opts, Subscriber.Options) do
    Nif.declare_subscriber(session, key_expr, opts)
  end

  @doc ~S"""
  Create a PullSubscriber for the given key expression.

  ## Examples

      iex> {:ok, session} = Zenohex.open()
      iex> Zenohex.Session.declare_pull_subscriber(session, "key/expression")
  """
  @spec declare_pull_subscriber(t(), String.t(), Subscriber.Options.t()) ::
          {:ok, PullSubscriber.t()} | {:error, reason :: String.t()}
  def declare_pull_subscriber(session, key_expr, opts \\ %Subscriber.Options{})
      when is_reference(session) and is_binary(key_expr) and is_struct(opts, Subscriber.Options) do
    Nif.declare_pull_subscriber(session, key_expr, opts)
  end

  @doc ~S"""
  Create a Quaryable for the given key expression.

  ## Examples

      iex> {:ok, session} = Zenohex.open()
      iex> Zenohex.Session.declare_queryable(session, "key/expression")
  """
  @spec declare_queryable(t(), String.t(), Queryable.Options.t()) ::
          {:ok, Queryable.t()} | {:error, reason :: String.t()}
  def declare_queryable(session, key_expr, opts \\ %Queryable.Options{})
      when is_reference(session) and is_binary(key_expr) and is_struct(opts, Queryable.Options) do
    Nif.declare_queryable(session, key_expr, opts)
  end

  @doc ~S"""
  Put data.

  ## Examples

      iex> {:ok, session} = Zenohex.open()
      iex> :ok = Zenohex.Session.put(session, "key/expression", "value")
      iex> :ok = Zenohex.Session.put(session, "key/expression", 0)
      iex> :ok = Zenohex.Session.put(session, "key/expression", 0.0)
  """
  @spec put(t(), String.t(), binary() | integer() | float()) ::
          :ok | {:error, reason :: String.t()}
  def put(session, key_expr, value)
      when is_reference(session) and is_binary(key_expr) and is_binary(value) do
    Nif.session_put_binary(session, key_expr, value)
  end

  def put(session, key_expr, value)
      when is_reference(session) and is_binary(key_expr) and is_integer(value) do
    Nif.session_put_integer(session, key_expr, value)
  end

  def put(session, key_expr, value)
      when is_reference(session) and is_binary(key_expr) and is_float(value) do
    Nif.session_put_float(session, key_expr, value)
  end

  @doc ~S"""
  Get reply receiver from the matching queryables in the system.

  ## Examples

      iex> {:ok, session} = Zenohex.open()
      iex> Zenohex.Session.get_reply_receiver(session, "key/**")
  """
  @spec get_reply_receiver(t(), String.t(), Query.Options.t()) ::
          {:ok, receiver()} | {:error, reason :: String.t()}
  def get_reply_receiver(session, selector, opts \\ %Query.Options{})
      when is_reference(session) and is_binary(selector) and is_struct(opts, Query.Options) do
    Nif.session_get_reply_receiver(session, selector, opts)
  end

  @doc ~S"""
  Query data from receiver.

  ## Examples

      iex> {:ok, session} = Zenohex.open()
      iex> {:ok, receiver} = Zenohex.Session.get_reply_receiver(session, "key/**")
      iex> Zenohex.Session.get_reply_timeout(receiver, 1000)
      {:error, :timeout}
  """
  @spec get_reply_timeout(receiver(), pos_integer()) ::
          {:ok, binary() | integer() | float()} | {:error, :timeout} | {:error, reason :: any()}
  def get_reply_timeout(receiver, timeout_us)
      when is_reference(receiver) and is_integer(timeout_us) and timeout_us > 0 do
    Nif.session_get_reply_timeout(receiver, timeout_us)
  end

  @doc ~S"""
  Delete data.

  ## Examples

      iex> {:ok, session} = Zenohex.open()
      iex> Zenohex.Session.delete(session, "key/expression")
      :ok
  """
  @spec delete(t(), String.t()) :: :ok | {:error, reason :: String.t()}
  def delete(session, key_expr) when is_reference(session) and is_binary(key_expr) do
    Nif.session_delete(session, key_expr)
  end
end
