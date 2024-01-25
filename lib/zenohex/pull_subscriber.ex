defmodule Zenohex.PullSubscriber do
  alias Zenohex.Nif

  @type t :: reference()

  @spec pull!(t()) :: :ok
  def pull!(pull_subscriber) do
    Nif.pull_subscriber_pull(pull_subscriber)
  end

  @spec recv_timeout!(t(), non_neg_integer()) :: integer() | float() | binary() | :timeout
  def recv_timeout!(pull_subscriber, timeout_us) do
    Nif.pull_subscriber_recv_timeout(pull_subscriber, timeout_us)
  end
end
