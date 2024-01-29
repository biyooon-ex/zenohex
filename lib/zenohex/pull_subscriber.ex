defmodule Zenohex.PullSubscriber do
  @moduledoc """
  Documentation for `#{__MODULE__}`.
  """

  alias Zenohex.Nif

  @type t :: reference()

  @doc """
  Pull data.

  ## Examples

      iex> session = Zenohex.open!()
      iex> subscriber = Zenohex.Session.declare_pull_subscriber!(session, "key/expression")
      iex> Zenohex.PullSubscriber.pull!(subscriber)
      :ok
  """
  @spec pull!(t()) :: :ok
  def pull!(pull_subscriber) when is_reference(pull_subscriber) do
    Nif.pull_subscriber_pull(pull_subscriber)
  end

  @doc """
  Receive data.

  ## Examples

      iex> session = Zenohex.open!()
      iex> subscriber = Zenohex.Session.declare_pull_subscriber!(session, "key/expression")
      iex> Zenohex.PullSubscriber.recv_timeout!(subscriber, 1000)
      :timeout
  """
  @spec recv_timeout!(t(), pos_integer()) :: integer() | float() | binary() | :timeout
  def recv_timeout!(pull_subscriber, timeout_us)
      when is_reference(pull_subscriber) and is_integer(timeout_us) and timeout_us > 0 do
    Nif.pull_subscriber_recv_timeout(pull_subscriber, timeout_us)
  end
end
