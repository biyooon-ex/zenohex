defmodule Zenohex.Examples.Session.Impl do
  @moduledoc false

  use GenServer

  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def put(key_expr, value) do
    GenServer.call(__MODULE__, {:put, key_expr, value})
  end

  def set_disconnected_cb(callback) do
    GenServer.call(__MODULE__, {:set_disconnected_cb, callback})
  end

  def delete(key_expr) do
    GenServer.call(__MODULE__, {:delete, key_expr})
  end

  def get(selector, callback) do
    GenServer.call(__MODULE__, {:get, selector, callback})
  end

  def init(args) do
    {:ok,
     %{
       session: Map.fetch!(args, :session),
       selector: nil,
       receiver: nil,
       callback: nil,
       disconnected_cb: fn -> nil end
     }}
  end

  def handle_call({:put, key_expr, value}, _from, state) do
    ret = Zenohex.Session.put(state.session, key_expr, value)
    {:reply, ret, state}
  end

  def handle_call({:set_disconnected_cb, callback}, _from, state) do
    {:reply, :ok, %{state | disconnected_cb: callback}}
  end

  def handle_call({:delete, key_expr}, _from, state) do
    :ok = Zenohex.Session.delete(state.session, key_expr)
    {:reply, :ok, state}
  end

  def handle_call({:get, selector, callback}, _from, state) do
    {:ok, receiver} = Zenohex.Session.get_reply_receiver(state.session, selector)
    send(self(), :get_reply)
    {:reply, :ok, %{state | selector: selector, receiver: receiver, callback: callback}}
  end

  def handle_info(:get_reply, state) do
    case Zenohex.Session.get_reply_timeout(state.receiver) do
      {:ok, sample} ->
        state.callback.(sample)
        send(self(), :get_reply)

      {:error, :timeout} ->
        send(self(), :get_reply)

      {:error, :disconnected} ->
        state.disconnected_cb.()

      {:error, error} ->
        Logger.error(inspect(error))
    end

    {:noreply, state}
  end
end
