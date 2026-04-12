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

      iex> System.put_env("ZENOH_CONFIG", "path/to/zenoh_config.json5")
      iex> {:ok, config} = Zenohex.Config.from_env()
      iex> is_binary(config)
      true
  """
  @spec from_env() :: {:ok, t()} | {:error, reason :: term()}
  def from_env() do
    case System.get_env("ZENOH_CONFIG") do
      nil -> {:error, "environment variable not found: ZENOH_CONFIG"}
      path -> Zenohex.Nif.config_from_env(path)
    end
  end

  @doc """
  Loads configuration from the file at the given path.

  ## Examples

      iex> {:ok, config} = Zenohex.Config.from_file("path/to/zenoh_config.json5")
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
      {:ok, "null"}
  """
  @spec get_json(t(), String.t()) :: {:ok, String.t()} | {:error, reason :: term()}
  defdelegate get_json(config, key), to: Zenohex.Nif, as: :config_get_json

  @doc """
  Inserts or updates a JSON5 configuration value at `key`, returning the updated config.

  If `value` is not valid JSON5 by itself (for example, `"peer"` passed as a bare
  identifier), this function retries by treating it as a plain string value.

  ## Examples

      iex> config = Zenohex.Config.default()
      iex> {:ok, updated} = Zenohex.Config.insert_json5(config, "scouting/delay", "100")
      iex> Zenohex.Config.get_json(updated, "scouting/delay")
      {:ok, "100"}

      iex> {:ok, updated2} = Zenohex.Config.insert_json5(config, "mode", "peer")
      iex> Zenohex.Config.get_json(updated2, "mode")
      {:ok, "\"peer\""}
  """
  @spec insert_json5(t(), String.t(), String.t()) :: {:ok, t()} | {:error, reason :: term()}
  def insert_json5(config, key, value)
      when is_binary(config) and is_binary(key) and is_binary(value) do
    case Zenohex.Nif.config_insert_json5(config, key, value) do
      {:ok, _} = ok ->
        ok

      {:error, _} ->
        quoted =
          value
          |> :json.encode()
          |> IO.iodata_to_binary()

        Zenohex.Nif.config_insert_json5(config, key, quoted)
    end
  end
end
