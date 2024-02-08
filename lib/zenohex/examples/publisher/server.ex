defmodule Zenohex.Examples.Publisher.Server do
  @moduledoc false

  use GenServer

  alias Zenohex.Session
  alias Zenohex.Publisher

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def put(value) do
    GenServer.call(__MODULE__, {:put, value})
  end

  def delete() do
    GenServer.call(__MODULE__, :delete)
  end

  def congestion_control(value) do
    GenServer.call(__MODULE__, {:congestion_control, value})
  end

  def priority(value) do
    GenServer.call(__MODULE__, {:priority, value})
  end

  def init(args) do
    session = Map.fetch!(args, :session)
    key_expr = Map.fetch!(args, :key_expr)
    {:ok, publisher} = Session.declare_publisher(session, key_expr)
    {:ok, %{publisher: publisher}}
  end

  def handle_call({:put, value}, _from, state) do
    :ok = Publisher.put(state.publisher, value)
    {:reply, :ok, state}
  end

  def handle_call(:delete, _from, state) do
    :ok = Publisher.delete(state.publisher)
    {:reply, :ok, state}
  end

  def handle_call({:congestion_control, value}, _from, state) do
    publisher = Publisher.congestion_control(state.publisher, value)
    {:reply, :ok, %{state | publisher: publisher}}
  end

  def handle_call({:priority, value}, _from, state) do
    publisher = Publisher.priority(state.publisher, value)
    {:reply, :ok, %{state | publisher: publisher}}
  end
end
