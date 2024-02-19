defmodule Zenohex.Examples.Subscriber do
  @moduledoc false

  use Supervisor

  require Logger

  alias Zenohex.Examples.Subscriber

  @doc "Start Subscriber."
  def start_link(args \\ %{}) when is_map(args) do
    session = Map.get(args, :session) || Zenohex.open!()
    key_expr = Map.get(args, :key_expr, "zenohex/examples/**")
    callback = Map.get(args, :callback, &Logger.debug(inspect(&1)))

    Supervisor.start_link(__MODULE__, %{session: session, key_expr: key_expr, callback: callback},
      name: __MODULE__
    )
  end

  @doc false
  def init(args) when is_map(args) do
    children = [
      {Subscriber.Impl, args}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc false
  def child_spec(args), do: super(args)
end
