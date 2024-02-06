defmodule Zenohex.Examples.Storage.Store do
  @behaviour Zenohex.StorageBehaviour

  use Agent

  require Logger

  alias Zenohex.KeyExpr

  def start_link(initial_state) do
    Agent.start_link(fn -> initial_state end, name: __MODULE__)
  end

  @impl true
  def put(key_expr, sample) do
    Agent.update(__MODULE__, fn map ->
      Map.put(map, key_expr, sample)
    end)
  end

  @impl true
  def delete(key_expr) do
    Agent.update(__MODULE__, fn map ->
      Map.delete(map, key_expr)
    end)
  end

  @impl true
  def get(key_expr) do
    Agent.get(
      __MODULE__,
      fn map ->
        samples = collect_samples(map, key_expr)

        if samples == [] do
          {:error, :not_found}
        else
          {:ok, samples}
        end
      end
    )
  end

  def dump() do
    Agent.get(__MODULE__, fn map -> map end)
  end

  defp collect_samples(map, key_expr) do
    Map.keys(map)
    |> Enum.filter(&KeyExpr.intersects?(&1, key_expr))
    |> Enum.reduce([], fn key, acc ->
      case Map.get(map, key) do
        nil -> acc
        sample -> [sample | acc]
      end
    end)
  end
end
