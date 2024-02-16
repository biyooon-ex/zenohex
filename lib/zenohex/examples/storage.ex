defmodule Zenohex.Examples.Storage do
  @moduledoc false

  use Supervisor

  alias Zenohex.Examples.Storage

  @doc "Start storage."
  def start_link(args \\ %{}) when is_map(args) do
    session = Map.get(args, :session) || Zenohex.open!()
    key_expr = Map.get(args, :key_expr, "zenohex/examples/**")
    Supervisor.start_link(__MODULE__, %{session: session, key_expr: key_expr}, name: __MODULE__)
  end

  @doc false
  def init(args) when is_map(args) do
    children = [
      {Storage.Store, %{}},
      {Storage.Subscriber, args},
      {Storage.Queryable, args}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc false
  def child_spec(args), do: super(args)
end
