defmodule Zenohex.Examples.Subscriber do
  @moduledoc false

  use GenServer

  require Logger

  def start_link(args) do
    name = Keyword.get(args, :name, __MODULE__)
    GenServer.start_link(__MODULE__, args, name: name)
  end

  def init(args) do
    session_id =
      Keyword.get(args, :session_id) ||
        Zenohex.Session.open() |> then(fn {:ok, session_id} -> session_id end)

    key_expr = Keyword.get(args, :key_expr, "key/expr")
    callback = Keyword.get(args, :callback, &Logger.debug("#{inspect(&1)}"))

    {:ok, subscriber_id} = Zenohex.Session.declare_subscriber(session_id, key_expr, self())

    {:ok,
     %{
       subscriber_id: subscriber_id,
       key_expr: key_expr,
       callback: callback
     }}
  end

  def handle_info(%Zenohex.Sample{} = sample, state) do
    %{callback: callback} = state

    callback.(sample)

    {:noreply, state}
  end
end
