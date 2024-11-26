defmodule Zenohex.Examples.Pong do
  @moduledoc false

  use Supervisor

  require Logger

  alias Zenohex.Examples.Pong

  @doc "Start Session"
  def start_link(args \\ %{}) when is_map(args) do
    session = Map.get(args, :session) || Zenohex.open!()
    ping_key_expr = Map.get(args, :ping_key_expr, "zenohex/examples/ping")
    pong_key_expr = Map.get(args, :pong_key_expr, "zenohex/examples/pong")
    callback = Map.get(args, :callback, &Logger.debug(inspect(&1)))

    Supervisor.start_link(__MODULE__, %{session: session, ping_key_expr: ping_key_expr, pong_key_expr: pong_key_expr, callback: callback}, name: __MODULE__)
  end

  @doc "Start Pong Process."
  @spec start_pong_process() :: :ok
  defdelegate start_pong_process(), to: Pong.Impl

  def init(args) when is_map(args) do
    IO.inspect(args, label: "Supervisor args")
    children = [
      {Pong.Impl, args}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc false
  def child_spec(args), do: super(args)

end
