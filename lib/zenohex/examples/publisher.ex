defmodule Zenohex.Examples.Publisher do
  @moduledoc false

  use Supervisor

  alias Zenohex.Examples.Publisher

  @doc "Start Publisher."
  def start_link(args \\ %{}) when is_map(args) do
    session = Map.get(args, :session) || Zenohex.open!()
    key_expr = Map.get(args, :key_expr, "zenohex/examples/pub")
    Supervisor.start_link(__MODULE__, %{session: session, key_expr: key_expr}, name: __MODULE__)
  end

  @doc "Put data."
  @spec put(integer() | float() | binary()) :: :ok
  defdelegate put(value), to: Publisher.Impl

  @doc "Delete data."
  @spec delete() :: :ok
  defdelegate delete(), to: Publisher.Impl

  @doc "Change congestion control."
  @spec congestion_control(Zenohex.Publisher.Options.congestion_control()) :: :ok
  defdelegate congestion_control(option), to: Publisher.Impl

  @doc "Change priority."
  @spec priority(Zenohex.Publisher.Options.priority()) :: :ok
  defdelegate priority(option), to: Publisher.Impl

  @doc false
  def init(args) when is_map(args) do
    children = [
      {Publisher.Impl, args}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc false
  def child_spec(args), do: super(args)
end
