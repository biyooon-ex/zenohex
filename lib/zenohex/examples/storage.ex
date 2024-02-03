defmodule Zenohex.Examples.Storage do
  use Supervisor

  alias Zenohex.Examples.Storage

  def start_link(args) when is_map(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) when is_map(args) do
    true = Map.has_key?(args, :session)
    true = Map.has_key?(args, :key_expr)

    children = [
      {Storage.Store, %{}},
      {Storage.Subscriber, args},
      {Storage.Queryable, args}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
