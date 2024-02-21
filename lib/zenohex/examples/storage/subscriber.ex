defmodule Zenohex.Examples.Storage.Subscriber do
  @moduledoc false

  use GenServer

  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    {:ok, subscriber} = Zenohex.Session.declare_subscriber(args.session, args.key_expr)
    send(self(), :loop)
    {:ok, %{subscriber: subscriber}}
  end

  def handle_info(:loop, state) do
    case Zenohex.Subscriber.recv_timeout(state.subscriber) do
      {:ok, sample} -> store(sample)
      {:error, :timeout} -> nil
      {:error, reason} -> Logger.error(inspect(reason))
    end

    send(self(), :loop)
    {:noreply, state}
  end

  defp store(sample) when is_struct(sample, Zenohex.Sample) do
    case sample.kind do
      :put -> Zenohex.Examples.Storage.Store.put(sample.key_expr, sample)
      :delete -> Zenohex.Examples.Storage.Store.delete(sample.key_expr)
    end
  end
end
