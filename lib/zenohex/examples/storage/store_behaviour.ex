defmodule Zenohex.Examples.Storage.StoreBehaviour do
  @moduledoc false

  @callback put(key_expr :: String.t(), sample :: Zenohex.Sample.t()) ::
              :ok | {:error, reason :: any()}
  @callback delete(key_expr :: String.t()) ::
              :ok | {:error, reason :: any()}
  @callback get(selector :: String.t()) ::
              {:ok, [Zenohex.Sample.t()]} | {:error, reason :: any()}
end
