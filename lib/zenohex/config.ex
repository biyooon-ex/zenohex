defmodule Zenohex.Config do
  @moduledoc """
  Utility functions for working with Zenoh session configurations.

  This module provides helpers to obtain default configuration,
  parse JSON5 strings, and manipulate nested config structures using Elixir functions.
  """

  @doc """
  Returns the default Zenoh configuration as a JSON5 binary.

  The returned configuration is valid input for `Zenohex.Session.open/1`.

  ## Examples

  Print the config in a readable form to check its contents.

      iex> config = Zenohex.Config.default()
      iex> config |> :json.decode() |> :json.format() |> IO.puts()
  """
  @spec default() :: binary()
  defdelegate default(), to: Zenohex.Nif, as: :config_default

  @doc false
  @spec from_json5(binary()) :: {:ok, binary()} | {:error, term()}
  defdelegate from_json5(binary), to: Zenohex.Nif, as: :config_from_json5

  @doc """
  Updates a key in a nested JSON binary.

  This function decodes the JSON, applies the given function to the value
  at the specified path, and re-encodes the result into a binary.

  ## Parameters

    - `config`: A JSON config binary.
    - `keys`: A list representing the nested path to update.
    - `fun`: A function to apply to the value at the specified path.

  ## Examples

      iex> config = Zenohex.Config.default()
      iex> Zenohex.Config.update_in(config, ["scouting", "delay"], fn _ -> 100 end)
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
