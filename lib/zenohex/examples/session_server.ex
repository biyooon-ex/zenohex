defmodule Zenohex.Examples.SessionServer do
  use GenServer

  require Logger

  alias Zenohex.Session

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def session() do
    GenServer.call(__MODULE__, :session)
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

  def init(_args) do
    {:ok, session} = Zenohex.open()

    {:ok,
     %{
       session: session,
       selector: nil,
       receiver: nil,
       callback: nil,
       disconnected_cb: fn -> nil end
     }}
  end

  def handle_call(:session, _from, state) do
    {:reply, state.session, state}
  end

  def handle_call({:put, key_expr, value}, _from, state) do
    ret = Session.put(state.session, key_expr, value)
    {:reply, ret, state}
  end

  def handle_call({:set_disconnected_cb, callback}, _from, state) do
    {:reply, :ok, %{state | disconnected_cb: callback}}
  end

  def handle_call({:delete, key_expr}, _from, state) do
    :ok = Session.delete(state.session, key_expr)
    {:reply, :ok, state}
  end

  def handle_call({:get, selector, callback}, _from, state) do
    {:ok, receiver} = Session.get_reply_receiver(state.session, selector)
    send(self(), :get_reply)
    {:reply, :ok, %{state | selector: selector, receiver: receiver, callback: callback}}
  end

  def handle_info(:get_reply, state) do
    case Session.get_reply_timeout(state.receiver, 1000) do
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
