defmodule Zenohex.Config do
  @spec default() :: binary()
  defdelegate default(), to: Zenohex.Nif, as: :config_default

  @spec from_json5(binary()) :: {:ok, binary()} | {:error, term()}
  defdelegate from_json5(binary), to: Zenohex.Nif, as: :config_from_json5
end
