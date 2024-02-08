defmodule Zenohex.PullSubscriber do
  @moduledoc """
  Documentation for `#{__MODULE__}`.
  """

  alias Zenohex.Nif
  alias Zenohex.Sample

  @type t :: reference()

  @doc """
  Pull data.

  ## Examples

      iex> {:ok, session} = Zenohex.open()
      iex> {:ok, pull_subscriber} = Zenohex.Session.declare_pull_subscriber(session, "key/expression")
      iex> Zenohex.PullSubscriber.pull(pull_subscriber)
      :ok
  """
  @spec pull(t()) :: :ok | {:error, reason :: any()}
  def pull(pull_subscriber) when is_reference(pull_subscriber) do
    Nif.pull_subscriber_pull(pull_subscriber)
  end

  @doc """
  Receive data.
  Normally users don't need to change the default timeout_us.

  ## Examples

      iex> {:ok, session} = Zenohex.open()
      iex> {:ok, pull_subscriber} = Zenohex.Session.declare_pull_subscriber(session, "key/expression")
      iex> Zenohex.PullSubscriber.recv_timeout(pull_subscriber)
      {:error, :timeout}
  """
  @spec recv_timeout(t(), pos_integer()) ::
          {:ok, Sample.t()}
          | {:error, :timeout}
          | {:error, :disconnected}
          | {:error, reason :: any()}
  def recv_timeout(pull_subscriber, timeout_us \\ 1000)
      when is_reference(pull_subscriber) and is_integer(timeout_us) and timeout_us > 0 do
    Nif.pull_subscriber_recv_timeout(pull_subscriber, timeout_us)
  end
end
