defmodule Zenohex.Subscriber do
  alias Zenohex.Nif

  @type t :: reference()
  @type reliability :: :best_effort | :reliable

  defmodule Options do
    defstruct reliability: :best_effort
  end

  @spec recv_timeout!(t(), non_neg_integer()) :: integer() | float() | binary() | :timeout
  def recv_timeout!(subscriber, timeout_us) do
    Nif.subscriber_recv_timeout(subscriber, timeout_us)
  end
end
