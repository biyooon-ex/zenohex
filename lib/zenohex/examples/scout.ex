defmodule Zenohex.Examples.Scout do
  @moduledoc """
  Example `GenServer` implementation of `Scout`
  using `Zenohex.Scouting.declare_scout/3`.

  This example demonstrates how to scout.

  For the actual implementation, please refer to the following,

  - #{Zenohex.MixProject.project()[:source_url]}/tree/main/#{Path.relative_to_cwd(__ENV__.file)}

  ## Examples

      iex> Zenohex.Examples.Scout.start_link([])
  """

  use GenServer

  require Logger

  @doc """
  Starts `#{__MODULE__}`.

  ## Parameters

  * `args` – a keyword list that can include the following keys:
    * `:what` – the target to scout (e.g., `:peer` or `:router`)
    * `:config` – the configuration used for scouting
    * `:callback` – a function to be called when a hello message is received
  """
  @spec start_link([
          {:what, Zenohex.Scouting.what()}
          | {:config, Zenohex.Config.t()}
          | {:callback, (Zenohex.Scouting.Hello.t() -> term())}
        ]) :: GenServer.on_start()
  def start_link(args) do
    name = Keyword.get(args, :name, __MODULE__)
    GenServer.start_link(__MODULE__, args, name: name)
  end

  @doc """
  Stops #{__MODULE__}
  """
  def stop(name \\ __MODULE__) do
    GenServer.call(name, :stop)
  end

  @doc false
  def child_spec(init_arg), do: super(init_arg)

  @doc false
  def init(args) do
    what = Keyword.get(args, :what, :peer)
    config = Keyword.get_lazy(args, :config, &Zenohex.Config.default/0)
    callback = Keyword.get(args, :callback, &Logger.debug("#{inspect(&1)}"))

    {:ok, scout} = Zenohex.Scouting.declare_scout(what, config, self())

    {:ok,
     %{
       scout: scout,
       callback: callback
     }}
  end

  def handle_info(%Zenohex.Scouting.Hello{} = hello, state) do
    state.callback.(hello)

    {:noreply, state}
  end

  def handle_call(:stop, _from, state) do
    reply = Zenohex.Scouting.stop_scout(state.scout)
    reason = :normal

    {:stop, reason, reply, state}
  end
end
