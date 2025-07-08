defmodule Zenohex.Example.Scout do
  @moduledoc false

  use GenServer

  require Logger

  def stop(name \\ __MODULE__) do
    GenServer.call(name, :stop)
  end

  def start_link(args) do
    name = Keyword.get(args, :name, __MODULE__)
    GenServer.start_link(__MODULE__, args, name: name)
  end

  def init(args) do
    what = Keyword.get(args, :what, :peer)
    config = Keyword.get(args, :config) || Zenohex.Config.default()
    callback = Keyword.get(args, :callback, &Logger.debug("#{inspect(&1)}"))

    {:ok, scout} = Zenohex.Nif.scouting_declare_scout(what, config, self())

    {:ok,
     %{
       scout: scout,
       callback: callback
     }}
  end

  def handle_info(%Zenohex.Hello{} = hello, state) do
    %{callback: callback} = state

    callback.(hello)

    {:noreply, state}
  end

  def handle_call(:stop, {pid, _ref} = _from, state) do
    %{scout: scout} = state

    {:stop, "stop called by #{inspect(pid)}", Zenohex.Nif.scouting_stop_scout(scout), state}
  end
end
