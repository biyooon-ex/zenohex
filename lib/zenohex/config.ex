defmodule Zenohex.Config do
  @type t :: String.t()

  @moduledoc """
  Utility functions for working with Zenoh session configurations.

  This module provides helpers to obtain default configuration,
  load from files or environment variables, parse JSON5 strings,
  and retrieve or update individual config keys.
  """

  @doc """
  Returns the default Zenoh configuration as a JSON binary.

  The returned configuration is valid input for `Zenohex.Session.open/1`.

  ## Examples

  Print the config in a readable form to check its contents.

      iex> config = Zenohex.Config.default()
      iex> config |> :json.decode() |> :json.format() |> IO.puts()
  """
  @spec default() :: t()
  defdelegate default(), to: Zenohex.Nif, as: :config_default

  @doc """
  Loads configuration from the file path specified by the `ZENOH_CONFIG` environment variable.

  ## Examples

      iex> {:ok, config} = Zenohex.Config.from_env()
      iex> is_binary(config)
      true
  """
  @spec from_env() :: {:ok, t()} | {:error, reason :: term()}
  def from_env() do
    case System.get_env("ZENOH_CONFIG") do
      nil ->
        {:error, "environment variable not found: ZENOH_CONFIG"}

      path ->
        from_file(path)
    end
  end

  @doc """
  Loads configuration from the file at the given path.

  ## Examples

      iex> {:ok, config} = Zenohex.Config.from_file("path/to/config.json5")
      iex> is_binary(config)
      true
  """
  @spec from_file(String.t()) :: {:ok, t()} | {:error, reason :: term()}
  defdelegate from_file(path), to: Zenohex.Nif, as: :config_from_file

  @doc false
  @spec from_json5(t()) :: {:ok, t()} | {:error, reason :: term()}
  defdelegate from_json5(binary), to: Zenohex.Nif, as: :config_from_json5

  @doc """
  Returns the JSON string of the configuration value at `key`.

  ## Examples

      iex> config = Zenohex.Config.default()
      iex> {:ok, value} = Zenohex.Config.get_json(config, "scouting/delay")
      iex> is_binary(value)
      true
  """
  @spec get_json(t(), String.t()) :: {:ok, String.t()} | {:error, reason :: term()}
  defdelegate get_json(config, key), to: Zenohex.Nif, as: :config_get_json

  @doc """
  Inserts or updates a JSON5 configuration value at `key`, returning the updated config.

  ## Examples

      iex> config = Zenohex.Config.default()
      iex> {:ok, updated} = Zenohex.Config.insert_json5(config, "scouting/delay", "100")
      iex> {:ok, "100"} = Zenohex.Config.get_json(updated, "scouting/delay")
  """
  @spec insert_json5(t(), String.t(), String.t()) :: {:ok, t()} | {:error, reason :: term()}
  defdelegate insert_json5(config, key, value), to: Zenohex.Nif, as: :config_insert_json5

  @deprecated "Use insert_json5/3 instead."
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
  @spec update_in(t(), [term(), ...], (term() -> term())) :: t()
  def update_in(config, keys, fun)
      when is_binary(config) and is_list(keys) and is_function(fun) do
    config
    |> :json.decode()
    |> Kernel.update_in(keys, fun)
    |> :json.encode()
    |> IO.iodata_to_binary()
  end
end
