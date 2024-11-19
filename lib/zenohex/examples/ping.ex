defmodule Zenohex.Examples.Ping do
  @moduledoc false

  use Supervisor

  require Logger

  alias Zenohex.Examples.Ping

  @doc "Start Session"
  def start_link(args \\ %{}) when is_map(args) do
    session = Map.get(args, :session) || Zenohex.open!()
    ping_key_expr = Map.get(args, :ping_key_expr, "zenohex/examples/ping")
    pong_key_expr = Map.get(args, :pong_key_expr, "zenohex/examples/pong")
    callback = Map.get(args, :callback, &Logger.debug(inspect(&1)))

    payload_size = Map.get(args, :payload_size, 64)
    warmup = Map.get(args, :warmup, 10)
    samples = Map.get(args, :samples, 10)

    Supervisor.start_link(__MODULE__, %{session: session, ping_key_expr: ping_key_expr, pong_key_expr: pong_key_expr, callback: callback, payload_size: payload_size, warmup: warmup, samples: samples}, name: __MODULE__)
  end

  @doc "Start Ping Process."
  @spec start_ping_process() :: :ok
  defdelegate start_ping_process(), to: Ping.Impl

  def init(args) when is_map(args) do
    IO.inspect(args, label: "Supervisor args")
    children = [
      {Ping.Impl, args}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc false
  def child_spec(args), do: super(args)

end
