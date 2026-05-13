defmodule Zenohex.ConfigMap do
  @type json_scalar :: nil | boolean() | number() | String.t()
  @type json_value :: json_scalar() | [json_value()] | %{optional(String.t()) => json_value()}
  @type t :: %{optional(String.t()) => json_value()}

  @moduledoc """
  Elixir-like map-centric utility functions for Zenoh session configurations.

  This module provides helpers to obtain default configuration,
  load from files or environment variables, parse JSON5 strings,
  and retrieve or update individual config keys as Elixir map values.

  This module automatically normalizes maps internally: atom keys become strings,
  charlist values are rejected, and only JSON-compatible types are accepted.

  This module is intended for configuring Zenoh naturally with Elixir maps.
  For the raw JSON / JSON5 API that tracks other language APIs (for example,
  `zenoh-python`), use `Zenohex.Config`.
  """

  @doc """
  Returns the default Zenoh configuration as an Elixir map.

  ## Examples

      iex> config = Zenohex.ConfigMap.default()
      iex> is_map(config)
      true
  """
  @spec default() :: t()
  def default() do
    {:ok, config} =
      Zenohex.Config.default()
      |> JSON.decode!()
      |> normalize_value()

    config
  end

  @doc """
  Returns the configuration value at `key` from an Elixir map config.

  ## Examples

      iex> {:ok, config} = Zenohex.ConfigMap.merge(%{}, %{mode: "peer", scouting: %{delay: 100}, connect: %{endpoints: ["tcp/localhost:7447"]}})
      iex> {:ok, "peer"} = Zenohex.ConfigMap.get(config, "mode")
      iex> {:ok, delay} = Zenohex.ConfigMap.get(config, "scouting/delay")
      iex> delay
      100
      iex> {:ok, endpoints} = Zenohex.ConfigMap.get(config, "connect/endpoints")
      iex> endpoints
      ["tcp/localhost:7447"]
  """
  @spec get(map(), String.t()) :: {:ok, json_value()} | {:error, reason :: term()}
  def get(config, key) when is_map(config) and is_binary(key) do
    get_in_data(config, key)
  end

  @doc """
  Inserts or updates a value at `key` using Elixir data types.

  The first argument must be an Elixir map config.

  ## Examples

      iex> {:ok, config} = Zenohex.ConfigMap.merge(%{}, %{mode: "client", scouting: %{delay: 500}, connect: %{endpoints: []}})
      iex> {:ok, updated1} = Zenohex.ConfigMap.insert(config, "mode", "peer")
      iex> {:ok, updated2} = Zenohex.ConfigMap.insert(updated1, "scouting/delay", 100)
      iex> {:ok, updated3} = Zenohex.ConfigMap.insert(updated2, "connect/endpoints", ["tcp/localhost:7447"])
      iex> {:ok, "peer"} = Zenohex.ConfigMap.get(updated3, "mode")
      iex> {:ok, 100} = Zenohex.ConfigMap.get(updated3, "scouting/delay")
      iex> {:ok, ["tcp/localhost:7447"]} = Zenohex.ConfigMap.get(updated3, "connect/endpoints")
  """
  @spec insert(map(), String.t(), json_value() | map()) :: {:ok, t()} | {:error, reason :: term()}
  def insert(config, key, value) when is_map(config) and is_binary(key) do
    with {:ok, normalized_value} <- normalize_value(value) do
      put_in_data(config, key, normalized_value)
    end
  end

  @doc """
  Loads configuration from `ZENOH_CONFIG` and returns it as an Elixir map.

  ## Examples

      iex> System.put_env("ZENOH_CONFIG", "path/to/zenoh_config.json5")
      iex> {:ok, config} = Zenohex.ConfigMap.from_env()
      iex> is_map(config)
      true
  """
  @spec from_env() :: {:ok, t()} | {:error, reason :: term()}
  def from_env() do
    Zenohex.Config.from_env()
    |> decode_config_result()
  end

  @doc """
  Loads configuration from a file and returns it as an Elixir map.

  ## Examples

      iex> {:ok, config} = Zenohex.ConfigMap.from_file("path/to/zenoh_config.json5")
      iex> is_map(config)
      true
  """
  @spec from_file(String.t()) :: {:ok, t()} | {:error, reason :: term()}
  def from_file(path) do
    Zenohex.Config.from_file(path)
    |> decode_config_result()
  end

  @doc """
  Parses a JSON5 configuration string and returns it as an Elixir map.

  ## Examples

      iex> json5 = File.read!("path/to/zenoh_config.json5")
      iex> {:ok, config} = Zenohex.ConfigMap.from_json5(json5)
      iex> is_map(config)
      true
  """
  @spec from_json5(Zenohex.Config.t()) :: {:ok, t()} | {:error, reason :: term()}
  def from_json5(binary) do
    Zenohex.Config.from_json5(binary)
    |> decode_config_result()
  end

  @doc """
  Merges Elixir map data into the configuration.

  Keys in `map` overwrite corresponding keys in `config`. Nested maps are merged
  recursively, so unrelated sub-keys in `config` are preserved.

  The `map` argument is normalized before merging.

  ## Examples

      iex> base = %{"mode" => "client", "scouting" => %{"delay" => 500, "other" => "value"}}
      iex> {:ok, updated} = Zenohex.ConfigMap.merge(base, %{mode: "peer", scouting: %{delay: 100}})
      iex> {:ok, "peer"} = Zenohex.ConfigMap.get(updated, "mode")
      iex> {:ok, 100} = Zenohex.ConfigMap.get(updated, "scouting/delay")
      iex> {:ok, "value"} = Zenohex.ConfigMap.get(updated, "scouting/other")
  """
  @spec merge(map(), map()) :: {:ok, t()} | {:error, reason :: term()}
  def merge(config, map) when is_map(config) and is_map(map) do
    with {:ok, normalized_map} <- normalize_value(map) do
      {:ok, deep_merge(config, normalized_map)}
    end
  end

  defp decode_json(binary) when is_binary(binary) do
    case JSON.decode(binary) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, reason} -> {:error, {:json_decode_failed, reason}}
    end
  end

  defp decode_config_result({:ok, config_binary}) do
    with {:ok, decoded} <- decode_json(config_binary) do
      normalize_value(decoded)
    end
  end

  defp decode_config_result({:error, _} = error), do: error

  defp get_in_data(data, key) when is_map(data) do
    path = split_key_path(key)
    fetch_path_value(data, path)
  end

  defp fetch_path_value(value, []), do: {:ok, value}

  defp fetch_path_value(data, [segment | rest]) when is_map(data) do
    case Map.fetch(data, segment) do
      {:ok, value} -> fetch_path_value(value, rest)
      :error -> {:error, :not_found}
    end
  end

  defp fetch_path_value(_data, _path), do: {:error, :not_found}

  defp put_in_data(data, key, value) when is_map(data) do
    path = split_key_path(key)
    access_path = Enum.map(path, &Access.key(&1, %{}))
    {:ok, put_in(data, access_path, value)}
  rescue
    error -> {:error, {:invalid_path, error}}
  end

  defp split_key_path(key) do
    key
    |> String.split("/", trim: true)
  end

  defp normalize_value(value) when is_map(value), do: normalize_map(value)

  defp normalize_value(value) when is_list(value) do
    if value != [] and List.ascii_printable?(value) do
      {:error,
       "charlist is not supported. Pass a binary string (\"peer\") or JSON-compatible list values."}
    else
      normalize_list(value)
    end
  end

  defp normalize_value(value)
       when is_binary(value) or is_boolean(value) or is_number(value) or is_nil(value) do
    {:ok, value}
  end

  defp normalize_value(value) do
    {:error, {:unsupported_value_type, value}}
  end

  defp normalize_map(map) do
    Enum.reduce_while(map, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
      with {:ok, normalized_key} <- normalize_map_key(key),
           {:ok, normalized_value} <- normalize_value(value) do
        {:cont, {:ok, Map.put(acc, normalized_key, normalized_value)}}
      else
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp normalize_list(list) do
    Enum.reduce_while(list, {:ok, []}, fn elem, {:ok, acc} ->
      case normalize_value(elem) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, normalized_list} -> {:ok, Enum.reverse(normalized_list)}
      {:error, _} = error -> error
    end
  end

  defp normalize_map_key(key) when is_binary(key), do: {:ok, key}
  defp normalize_map_key(key) when is_atom(key), do: {:ok, Atom.to_string(key)}

  defp normalize_map_key(key) do
    {:error, {:unsupported_key_type, key}}
  end

  defp deep_merge(base, override) when is_map(base) and is_map(override) do
    Map.merge(base, override, fn _key, base_val, override_val ->
      if is_map(base_val) and is_map(override_val) do
        deep_merge(base_val, override_val)
      else
        override_val
      end
    end)
  end
end
