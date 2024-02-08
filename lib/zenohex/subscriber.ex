defmodule Zenohex.Subscriber do
  @moduledoc """
  Documentation for `#{__MODULE__}`.
  """

  alias Zenohex.Nif
  alias Zenohex.Sample

  @opaque t :: reference()

  defmodule Options do
    @moduledoc """
    Documentation for `#{__MODULE__}`.
    """

    @type t :: %__MODULE__{reliability: reliability()}
    @type reliability :: :best_effort | :reliable
    defstruct reliability: :best_effort
  end

  @doc """
  Receive data.

  ## Examples

      iex> {:ok, session} = Zenohex.open()
      iex> {:ok, subscriber} = Zenohex.Session.declare_subscriber(session, "key/expression")
      iex> Zenohex.Subscriber.recv_timeout(subscriber, 1000)
      {:error, :timeout}
  """
  @spec recv_timeout(t(), pos_integer()) ::
          {:ok, Sample.t()}
          | {:error, :timeout}
          | {:error, :disconnected}
          | {:error, reason :: any()}
  def recv_timeout(subscriber, timeout_us)
      when is_reference(subscriber) and is_integer(timeout_us) and timeout_us > 0 do
    Nif.subscriber_recv_timeout(subscriber, timeout_us)
  end
end
