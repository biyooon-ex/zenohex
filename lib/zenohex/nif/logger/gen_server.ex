defmodule Zenohex.Nif.Logger.GenServer do
  use GenServer

  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    :ok = Zenohex.Nif.Logger.init(self())
    {:ok, %{}}
  end

  def handle_info({level, message}, state) do
    case level do
      :debug -> Logger.debug(message)
      :info -> Logger.info(message)
      :warning -> Logger.warning(message)
      :error -> Logger.error(message)
    end

    {:noreply, state}
  end
end
