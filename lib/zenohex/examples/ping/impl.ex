defmodule Zenohex.Examples.Ping.Impl do
  @moduledoc false

  use GenServer

  require Logger

  defmodule Measurement do
    defstruct measurement_time: nil, send_time: nil, recv_time: nil

    @type t() :: %__MODULE__{
            measurement_time: DateTime.t(),
            send_time: integer(),
            recv_time: integer()
          }
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def start_ping_process() do
    GenServer.call(__MODULE__, :start_ping_process)
  end

  def init(args) do
    IO.inspect(args, label: "Ping.Impl args")

    session = Map.fetch!(args, :session)
    ping_key_expr = Map.fetch!(args, :ping_key_expr)
    pong_key_expr = Map.fetch!(args, :pong_key_expr)
    callback = Map.fetch!(args, :callback)
    payload_size = Map.fetch!(args, :payload_size)
    warmup = Map.fetch!(args, :warmup)
    samples = Map.fetch!(args, :samples)

    {:ok, subscriber} = Zenohex.Session.declare_subscriber(session, pong_key_expr)
    {:ok, publisher} = Zenohex.Session.declare_publisher(session, ping_key_expr)

    value = Enum.map(0..(payload_size-1), fn i -> rem(i, 10) end)
    data = :binary.list_to_bin(value)
    IO.inspect(data, label: "Generated data")

    state = %{publisher: publisher, subscriber: subscriber, callback: callback, payload_size: payload_size, warmup: warmup, samples: samples, data: data}
    {:ok, state}
  end

  def handle_call(:start_ping_process, _from, state) do
    IO.inspect(state, label: "State in ping_loop")
    IO.puts("Warming up for #{state.warmup}s...")
    warmup_end = DateTime.utc_now() |> DateTime.add(state.warmup, :second)
    state = Map.put(state, :warmup_end, warmup_end)
    send(self(), :warmup_loop)

    {:reply, :ok, state}
  end

  def handle_info(:warmup_loop, state) do

    current_time = DateTime.utc_now()

    if DateTime.compare(current_time, state.warmup_end) == :lt do
      :ok = Zenohex.Publisher.put(state.publisher, state.data)
      recv_timeout(state)
      send(self(), :warmup_loop)
      {:noreply, state}
    else
      IO.puts("Warmup complete")
      send(self(), :measurement)
      {:noreply, state}
    end
  end

  def handle_info(:measurement, state) do
    sample_list = Enum.reduce(0..state.samples, [],
    fn _i, acc ->
      write_time = System.monotonic_time(:nanosecond)
      :ok = Zenohex.Publisher.put(state.publisher, state.data)
      recv_timeout(state)
      end_time = System.monotonic_time(:nanosecond)
      elapsed_time = end_time - write_time

      [elapsed_time | acc]
    end)

    sample_list = Enum.reverse(sample_list)
    Process.sleep(100)

    Enum.with_index(sample_list)
    |> Enum.each(
    fn{rtt, i}
    -> IO.puts("#{state.payload_size} bytes: seq=#{i} rtt=#{rtt}μs lat=#{rtt / 2}μs")
    end)

    {:noreply, state}
  end

  def handle_info(:loop, state) do
    recv_timeout(state)
    {:noreply, state}
  end


  defp recv_timeout(state) do
    case Zenohex.Subscriber.recv_timeout(state.subscriber) do
      {:ok, sample} ->
        state.callback.(sample)
        send(self(), :loop)

      {:error, :timeout} ->
        send(self(), :loop)

      {:error, error} ->
        Logger.error(inspect(error))
    end
  end


end
