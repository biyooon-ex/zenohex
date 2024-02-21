defmodule Zenohex.Examples.Session do
  @moduledoc false

  use Supervisor

  alias Zenohex.Examples.Session

  @doc "Start Session."
  def start_link(args \\ %{}) when is_map(args) do
    session = Map.get(args, :session) || Zenohex.open!()
    Supervisor.start_link(__MODULE__, %{session: session}, name: __MODULE__)
  end

  @doc "Put data."
  @spec put(String.t(), integer() | float() | binary()) :: :ok
  defdelegate put(key_expr, value), to: Session.Impl

  @doc "Delete data."
  @spec delete(String.t()) :: :ok
  defdelegate delete(key_expr), to: Session.Impl

  @doc "Set disconnected callback."
  @spec set_disconnected_cb(function) :: :ok
  defdelegate set_disconnected_cb(callback), to: Session.Impl

  @doc "Get data."
  @spec get(String.t(), function()) :: :ok
  defdelegate get(selector, callback), to: Session.Impl

  @doc false
  def init(args) when is_map(args) do
    children = [
      {Session.Impl, args}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc false
  def child_spec(args), do: super(args)
end
