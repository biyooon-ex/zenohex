defmodule Zenohex.Examples.Plugins.StorageBackendFs do
  @moduledoc """
  Example usage of the [zenoh-plugin-storage-manager](https://zenoh.io/docs/manual/plugin-storage-manager/).

  This example uses [zenoh-backend-filesystem](https://github.com/eclipse-zenoh/zenoh-backend-filesystem)
  as the backend.

  The plugin configuration file is located at `test/support/fixtures/STORAGE_BACKEND_FS_CONFIG.json5`.
  Please refer to `STORAGE_BACKEND_FS_CONFIG.json5` for the configuration details.

  If the plugin fails to load, make sure that the followings exist

    - `libzenoh_backend_fs.so`
    - `libzenoh_plugin_storage_manager.so`

  under the `search_dirs` specified in the configuration.
  If they exist, verify that their versions are compatible with the `zenoh` version used by `zenohex`.

  For the actual implementation, please refer to the following,

  - #{Zenohex.MixProject.project()[:source_url]}/tree/main/#{Path.relative_to_cwd(__ENV__.file)}

  ## Example

      iex> Zenohex.Examples.Plugins.StorageBackendFs.start_link []
      {:ok, #PID<...>}
      iex> Zenohex.put("demo/example/file_a", "data_a")
      :ok
      iex> Zenohex.put("demo/example/file_b", "data_b")
      :ok
      iex> Zenohex.get("demo/example/**", 100)
      {:ok, [%Zenohex.Sample{}, %Zenohex.Sample{}]}

  """

  use GenServer

  @doc """
  Starts #{__MODULE__}.
  """
  @spec start_link([]) :: GenServer.on_start()
  def start_link(args) do
    name = Keyword.get(args, :name, __MODULE__)
    GenServer.start_link(__MODULE__, args, name: name)
  end

  @doc false
  def child_spec(args), do: super(args)

  @doc false
  def init(_args) do
    :ok = Zenohex.Nif.Logger.enable()
    :ok = Zenohex.Nif.Logger.set_level(:info)
    :ok = Zenohex.Nif.Logger.set_target("zenoh")

    session_id =
      File.read!("test/support/fixtures/STORAGE_BACKEND_FS_CONFIG.json5")
      |> Zenohex.Session.open()
      |> then(fn {:ok, session_id} -> session_id end)

    {:ok,
     %{
       # NOTE: You must retain the session_id.
       #       If it gets garbage-collected, the session will be closed automatically.
       session_id: session_id
     }}
  end
end
