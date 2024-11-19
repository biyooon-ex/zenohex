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
    IO.inspect(value, label: "Generated value")
    data = :binary.list_to_bin(value)
    IO.inspect(data, label: "Generated data")

    state = %{publisher: publisher, subscriber: subscriber, callback: callback, payload_size: payload_size, warmup: warmup, samples: samples, data: data}
    {:ok, state}
  end

  def handle_call(:start_ping_process, _from, state) do
    IO.puts("Warming up for #{state.warmup}s...")
    warmup_end = DateTime.utc_now() |> DateTime.add(state.warmup, :second)
    state = %{state | warmup_end: warmup_end}
    warmup_loop_run(state)

    send(self(), :measurement)

    {:reply, :ok, state}
  end

  def handle_call(:measurement, _from, state) do
    sample_list = Enum.reduce(0..state.samples, [],
    fn _i, acc ->
      write_time = DateTime.utc_now()
      state.publisher.put(state.data)
      recv_timeout(state)

      [round(DateTime.diff(DateTime.utc_now(), write_time)) | acc]
    end)

    sample_list = Enum.reverse(sample_list)

    Enum.with_index(sample_list)
    |> Enum.each(
    fn{i, rtt}
    -> IO.puts("#{state.payload_size} bytes: seq=#{i} rtt=#{rtt}μs lat=#{rtt / 2}μs")
    end)
  end


  defp warmup_loop_run(state) do
    current_time = DateTime.utc_now()

    if current_time < state.warmup_end do
      state.publisher.put(state.data)
      recv_timeout(state)
      warmup_loop_run(state)
    else
      :ok
    end

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
