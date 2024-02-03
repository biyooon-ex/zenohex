defmodule Zenohex.Examples.Storage.Store do
  @behaviour Zenohex.StorageBehaviour

  use Agent

  require Logger

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
        case Map.get(map, key_expr) do
          nil -> {:error, :not_found}
          sample -> {:ok, [sample]}
        end
      end
    )
  end

  def dump() do
    Agent.get(__MODULE__, fn map -> map end)
  end
end
