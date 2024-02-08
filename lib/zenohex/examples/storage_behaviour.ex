defmodule Zenohex.Examples.StorageBehaviour do
  alias Zenohex.Sample

  @callback put(key_expr :: String.t(), sample :: Sample.t()) :: :ok | {:error, reason :: any()}
  @callback delete(key_expr :: String.t()) :: :ok | {:error, reason :: any()}
  @callback get(selector :: String.t()) :: {:ok, [Sample.t()]} | {:error, reason :: any()}
end
