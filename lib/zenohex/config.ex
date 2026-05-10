defmodule Zenohex.Config do
  @type t :: String.t()
  @type json_scalar :: nil | boolean() | number() | String.t()
  @type json_value :: json_scalar() | [json_value()] | %{optional(String.t()) => json_value()}
  @type data_t :: %{optional(String.t()) => json_value()}

  @moduledoc """
  Utility functions for working with Zenoh session configurations.

  ## Map-centric API

  Use these as the primary API when working with Elixir data structures.

  - `default_map/0`
  - `from_map/1`
  - `put/2`
  - `get/2`
  - `insert/3`
  - `from_env_map/0`
  - `from_file_map/1`
  - `from_json5_map/1`

  ## Raw JSON / JSON5 API

  Use these when you explicitly want JSON/JSON5 string I/O.

  - `default/0`
  - `from_env/0`
  - `from_file/1`
  - `from_json5/1`
  - `get_json/2`
  - `insert_json5/3`
  """

  @doc """
  Returns the default Zenoh configuration as an Elixir map.

  ## Examples

      iex> config = Zenohex.Config.default_map()
      iex> is_map(config)
      true
  """
  @spec default_map() :: data_t()
  def default_map() do
    default()
    |> JSON.decode!()
  end

  @doc """
  Builds normalized configuration map from Elixir data.

  Map keys are normalized to strings recursively.

  ## Examples

      iex> {:ok, config} = Zenohex.Config.from_map(%{mode: "peer", scouting: %{delay: 100}})
      iex> is_map(config)
      true
  """
  @spec from_map(map()) :: {:ok, data_t()} | {:error, reason :: term()}
  def from_map(map) when is_map(map) do
    normalize_data(map)
  end

  @doc """
  Replaces the whole configuration with Elixir map data.

  The returned value is always a normalized Elixir map with string keys.

  ## Examples

      iex> {:ok, config} = Zenohex.Config.default_map()
      iex> {:ok, updated} = Zenohex.Config.put(config, %{mode: "peer"})
      iex> {:ok, "peer"} = Zenohex.Config.get(updated, "mode")

      iex> {:ok, updated1} = Zenohex.Config.put(config, %{scouting: %{delay: 100}})
      iex> {:ok, 100} = Zenohex.Config.get(updated1, "scouting/delay")

      iex> {:ok, updated2} = Zenohex.Config.put(config, %{connect: %{endpoints: ["tcp/localhost:7447"]}})
      iex> {:ok, ["tcp/localhost:7447"]} = Zenohex.Config.get(updated2, "connect/endpoints")
  """
  @spec put(t() | map(), map()) :: {:ok, data_t()} | {:error, reason :: term()}
  def put(_config, map) when is_map(map) do
    normalize_data(map)
  end

  @doc """
  Returns the configuration value at `key` as an Elixir data value.

  This function accepts either canonical JSON config binary or Elixir map data.
  For map inputs, keys are normalized to strings before lookup.

  ## Examples

      ### Read from a canonical JSON config binary
      iex> {:ok, config} = Zenohex.Config.from_file("path/to/zenoh_config.json5")
      iex> {:ok, delay} = Zenohex.Config.get(config, "scouting/delay")
      iex> delay
      500

      iex> {:ok, endpoints} = Zenohex.Config.get(config, "connect/endpoints")
      iex> endpoints
      []

      ### Read from an Elixir map
      iex> {:ok, config} = Zenohex.Config.from_map(%{scouting: %{delay: 100}})
      iex> {:ok, delay} = Zenohex.Config.get(config, "scouting/delay")
      iex> delay
      100

      iex> {:ok, config} = Zenohex.Config.from_map(%{scouting: %{delay: 100}, connect: %{endpoints: []}})
      iex> {:ok, endpoints} = Zenohex.Config.get(config, "connect/endpoints")
      iex> endpoints
      []

      iex> {:ok, config} = Zenohex.Config.from_map(%{connect: %{endpoints: ["tcp/localhost:7447"]}})
      iex> {:ok, endpoints} = Zenohex.Config.get(config, "connect/endpoints")
      iex> endpoints
      ["tcp/localhost:7447"]
  """
  @spec get(t() | map(), String.t()) :: {:ok, json_value()} | {:error, reason :: term()}
  def get(config, key) when is_binary(config) and is_binary(key) do
    with {:ok, json} <- get_json(config, key),
         {:ok, decoded} <- decode_json(json) do
      {:ok, decoded}
    end
  end

  def get(config, key) when is_map(config) and is_binary(key) do
    with {:ok, normalized} <- normalize_data(config),
         {:ok, value} <- get_in_data(normalized, key) do
      {:ok, value}
    end
  end

  @doc """
  Inserts or updates a value at `key` using Elixir data types.

  This function accepts either canonical JSON config binary or Elixir map data.
  The updated value is always returned as an Elixir map with string keys.

  ## Examples

      ### Update a canonical JSON config binary
      iex> {:ok, config} = Zenohex.Config.from_file("path/to/zenoh_config.json5")
      iex> {:ok, updated} = Zenohex.Config.insert(config, "scouting/delay", 100)
      iex> {:ok, 100} = Zenohex.Config.get(updated, "scouting/delay")

      ### Update an Elixir map
      iex> {:ok, config} = Zenohex.Config.from_map(%{scouting: %{delay: 500}})
      iex> {:ok, updated} = Zenohex.Config.insert(config, "scouting/delay", 100)
      iex> {:ok, 100} = Zenohex.Config.get(updated, "scouting/delay")

      ### Update a nested scouting map directly
      iex> {:ok, config} = Zenohex.Config.from_map(%{scouting: %{delay: 500}})
      iex> {:ok, updated} = Zenohex.Config.insert(config, "scouting", %{delay: 100})
      iex> {:ok, 100} = Zenohex.Config.get(updated, "scouting/delay")

      ### Update scouting/delay directly
      iex> {:ok, config} = Zenohex.Config.from_map(%{scouting: %{delay: 500}})
      iex> {:ok, updated} = Zenohex.Config.insert(config, "scouting/delay", 100)
      iex> {:ok, 100} = Zenohex.Config.get(updated, "scouting/delay")

      ### Update connect endpoints directly
      iex> {:ok, config} = Zenohex.Config.from_map(%{connect: %{endpoints: []}})
      iex> {:ok, updated} = Zenohex.Config.insert(config, "connect", %{endpoints: ["tcp/localhost:7447"]})
      iex> {:ok, ["tcp/localhost:7447"]} = Zenohex.Config.get(updated, "connect/endpoints")
  """
  @spec insert(t() | map(), String.t(), json_value() | map()) ::
          {:ok, data_t()} | {:error, reason :: term()}
  def insert(config, key, value) when is_binary(config) and is_binary(key) do
    with {:ok, normalized_config} <- decode_config_result({:ok, config}),
         {:ok, normalized_value} <- normalize_value(value),
         {:ok, updated} <- put_in_data(normalized_config, key, normalized_value) do
      {:ok, updated}
    end
  end

  def insert(config, key, value) when is_map(config) and is_binary(key) do
    with {:ok, normalized} <- normalize_data(config),
         {:ok, normalized_value} <- normalize_value(value),
         {:ok, updated} <- put_in_data(normalized, key, normalized_value) do
      {:ok, updated}
    end
  end

  @doc """
  Loads configuration from `ZENOH_CONFIG` and returns it as an Elixir map.

  ## Examples

      iex> System.put_env("ZENOH_CONFIG", "path/to/zenoh_config.json5")
      iex> {:ok, config} = Zenohex.Config.from_env_map()
      iex> is_map(config)
      true
  """
  @spec from_env_map() :: {:ok, data_t()} | {:error, reason :: term()}
  def from_env_map() do
    from_env()
    |> decode_config_result()
  end

  @doc """
  Loads configuration from a file and returns it as an Elixir map.

  ## Examples

      iex> {:ok, config} = Zenohex.Config.from_file_map("path/to/zenoh_config.json5")
      iex> is_map(config)
      true
  """
  @spec from_file_map(String.t()) :: {:ok, data_t()} | {:error, reason :: term()}
  def from_file_map(path) do
    from_file(path)
    |> decode_config_result()
  end

  @doc """
  Parses a JSON5 configuration string and returns it as an Elixir map.

  ## Examples

      iex> json5 = File.read!("path/to/zenoh_config.json5")
      iex> {:ok, config} = Zenohex.Config.from_json5_map(json5)
      iex> is_map(config)
      true
  """
  @spec from_json5_map(t()) :: {:ok, data_t()} | {:error, reason :: term()}
  def from_json5_map(binary) do
    from_json5(binary)
    |> decode_config_result()
  end

  @doc """
  Returns the default Zenoh configuration as a JSON binary.

  The returned configuration is valid input for `Zenohex.Session.open/1`.

  ## Examples

  Print the config in a readable form to check its contents.

      iex> config = Zenohex.Config.default()
      iex> config |> JSON.decode!() |> IO.inspect(pretty: true)
  """
  @spec default() :: t()
  defdelegate default(), to: Zenohex.Nif, as: :config_default

  @doc """
  Loads configuration from the file path specified by the `ZENOH_CONFIG` environment variable.

  ## Examples

      ### Set the environment variable and load the config
      $ ZENOH_CONFIG=path/to/zenoh_config.json5 iex -S mix
      iex> {:ok, config} = Zenohex.Config.from_env()
      iex> is_binary(config)
      true

      ### Set the environment variable in IEx
      $ unset ZENOH_CONFIG && iex -S mix
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

  @doc """
  Parses a JSON5 configuration string and returns canonical JSON.

  This is useful when you already have configuration content in memory,
  such as text loaded from a file, template output, or environment-driven
  string construction.

  ## Examples

      iex> json5 = File.read!("path/to/zenoh_config.json5")
      iex> {:ok, config} = Zenohex.Config.from_json5(json5)
      iex> is_binary(config)
      true
  """
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

  `value` should be a valid JSON5 string (e.g., `"500"`, `"true"`, or `"\"peer\""`).
  If `value` is not valid JSON5 format (for example, a plain string like `"peer"`
  missing its quotes), this function automatically quotes it (encodes as a JSON string)
  and retries the insertion.

  A list value (e.g., `["tcp/localhost:7447"]`) is also accepted and encoded as a JSON
  array before insertion.
  Printable ASCII `charlist` values (e.g., single-quoted text like `'peer'`) are
  rejected to avoid accidentally inserting a list of integer codepoints. Other
  non-ASCII charlists are treated as lists and may be encoded as JSON arrays of integers.

  ## Examples

      iex> config = Zenohex.Config.default()
      iex> {:ok, updated} = Zenohex.Config.insert_json5(config, "scouting/delay", "100")
      iex> Zenohex.Config.get_json(updated, "scouting/delay")
      {:ok, "100"}

      ### Pass a valid JSON5 string (manually quoted)
      iex> {:ok, updated1} = Zenohex.Config.insert_json5(config, "mode", "\"peer\"")
      iex> Zenohex.Config.get_json(updated1, "mode")
      {:ok, "\"peer\""}

      ### Pass a plain string (automatically quoted by this function)
      iex> {:ok, updated2} = Zenohex.Config.insert_json5(config, "mode", "client")
      iex> Zenohex.Config.get_json(updated2, "mode")
      {:ok, "\"client\""}

      iex> {:ok, updated3} = Zenohex.Config.insert_json5(config, "connect/endpoints", ["tcp/localhost:7447"])
      iex> Zenohex.Config.get_json(updated3, "connect/endpoints")
      {:ok, "[\"tcp/localhost:7447\"]"}

  > #### Migration from `update_in/3` {: .info}
  > The function `update_in/3` has been removed in v0.9.0.
  > For updating Zenoh configurations, please use `insert_json5/3` instead.

  ```elixir
  ### Past usage with `update_in/3`:
  Zenohex.Config.update_in(config, ["scouting", "delay"], fn _ -> 100 end)
  ### Use `insert_json5/3` with the key path joined by `/`:
  Zenohex.Config.insert_json5(config, "scouting/delay", "100")
  ```
  """
  @spec insert_json5(t(), String.t(), String.t() | list()) ::
          {:ok, t()} | {:error, reason :: term()}
  def insert_json5(config, key, value)
      when is_binary(config) and is_binary(key) and is_list(value) do
    if value != [] and List.ascii_printable?(value) do
      {:error,
       "charlist is not supported for insert_json5/3. Pass a binary string (\"peer\") or a JSON array list."}
    else
      try do
        encoded_value = value |> JSON.encode_to_iodata!() |> IO.iodata_to_binary()
        insert_json5(config, key, encoded_value)
      rescue
        error -> {:error, {:json_encode_failed, error}}
      end
    end
  end

  def insert_json5(config, key, value)
      when is_binary(config) and is_binary(key) and is_binary(value) do
    case Zenohex.Nif.config_insert_json5(config, key, value) do
      {:ok, _updated_config} = result ->
        result

      {:error, _reason} = original_error ->
        # If the value is not a valid JSON5 format (e.g., `"peer"`),
        # retry by quoting it as a JSON string.
        # If the retry also fails, return the original error.
        quoted_value = JSON.encode!(value)

        case Zenohex.Nif.config_insert_json5(config, key, quoted_value) do
          {:ok, _updated_config} = result -> result
          {:error, _reason} -> original_error
        end
    end
  end

  defp decode_json(binary) when is_binary(binary) do
    case JSON.decode(binary) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, reason} -> {:error, {:json_decode_failed, reason}}
    end
  end

  defp decode_config_result({:ok, config_binary}) do
    with {:ok, decoded} <- decode_json(config_binary),
         {:ok, normalized} <- normalize_data(decoded) do
      {:ok, normalized}
    end
  end

  defp decode_config_result({:error, _} = error), do: error

  defp get_in_data(data, key) when is_map(data) do
    path = split_key_path(key)

    case get_in(data, Enum.map(path, &Access.key(&1))) do
      nil -> {:error, :not_found}
      value -> {:ok, value}
    end
  end

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
    |> Enum.reject(&(&1 == ""))
  end

  defp normalize_data(data) when is_map(data) do
    normalize_map(data)
  end

  defp normalize_data(data) do
    {:error, {:config_must_be_map, data}}
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
end
