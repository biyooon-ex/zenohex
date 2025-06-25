defmodule Zenohex.Config do
  @spec default() :: binary()
  defdelegate default(), to: Zenohex.Nif, as: :config_default

  @spec from_json5(binary()) :: {:ok, binary()} | {:error, term()}
  defdelegate from_json5(binary), to: Zenohex.Nif, as: :config_from_json5

  @doc """
  Updates a key in a nested JSON binary.

  ## Example

      iex> config = Zenohex.Config.default()
      iex> Zenohex.Config.update_in(config, ["scouting", "delay"], fn :null -> delay end)
  """
  @spec update_in(binary(), [term(), ...], (term() -> term())) :: binary()
  def update_in(config, keys, fun) when is_list(keys) and is_function(fun) do
    # NOTE: Use :json.format/1 instead of :json.encode/1 to confirm easily
    config
    |> :json.decode()
    |> Kernel.update_in(keys, fun)
    |> :json.format()
    |> IO.iodata_to_binary()
  end
end
