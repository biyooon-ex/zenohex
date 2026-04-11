defmodule Zenohex.Matching do
  @moduledoc """
  Interface for querying current matching status and listening for status changes
  for publishers and queriers.

  Matching is supported for publisher and querier entities.
  """

  @type entity_id :: Zenohex.Publisher.id() | Zenohex.Querier.id()
  @type listener_id :: reference()

  defmodule Status do
    @moduledoc """
    Matching status for a publisher or querier.
    """

    @type t :: %__MODULE__{matching: boolean()}
    defstruct matching: false
  end

  @doc """
  Returns the current matching status for a publisher or querier.
  """
  @spec status(entity_id()) :: {:ok, boolean()} | {:error, reason :: term()}
  defdelegate status(entity_id), to: Zenohex.Nif, as: :matching_status

  @doc """
  Declares a matching listener for a publisher or querier.

  Status updates are delivered to `pid` as `%Zenohex.Matching.Status{}` messages.

  > ### Important {: .info}
  >
  > The returned `listener_id` must be held for as long as the listener is in use.
  > If it is not held and gets garbage-collected by the BEAM,
  > the underlying listener in Rust will be automatically dropped.
  """
  @spec declare_listener(entity_id(), pid()) :: {:ok, listener_id()} | {:error, reason :: term()}
  defdelegate declare_listener(entity_id, pid \\ self()),
    to: Zenohex.Nif,
    as: :matching_declare_listener

  @doc """
  Undeclares the matching listener identified by the given ID.
  """
  @spec undeclare_listener(listener_id()) :: :ok | {:error, reason :: term()}
  defdelegate undeclare_listener(listener_id),
    to: Zenohex.Nif,
    as: :matching_undeclare_listener
end
