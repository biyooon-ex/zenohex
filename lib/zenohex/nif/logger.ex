defmodule Zenohex.Nif.Logger do
  @moduledoc """
  Developer utility for interacting with the native logger.

  This module provides functions to enable, disable, and configure
  logging from the underlying NIF layer.

  When enabled, log messages from the native code are forwarded
  to the Elixir `Logger` system via Zenohex.Nif.Logger.GenServer.

  **By default, logging is disabled.**
  You must explicitly call `enable/0` to start receiving logs from the NIF layer.

  This module is intended for debugging and development use only,
  and should typically not be used in production environments.

  ## Examples

      iex> :ok = Zenohex.Nif.Logger.enable()
      iex> :ok = Zenohex.Nif.Logger.set_level(:info)
      iex> :ok = Zenohex.Nif.Logger.set_target("zenoh")
      iex> {:ok, session_id} = Zenohex.Session.open()

      11:12:16.162 [info] [zenoh::net::runtime] Using ZID: 600e0683e440f79e2e06053232748346

      11:12:16.166 [info] [zenoh::net::runtime::orchestrator] Zenoh can be reached at: tcp/[fe80::dead:beef:cafe:1234]:45215

      11:12:16.166 [info] [zenoh::net::runtime::orchestrator] Zenoh can be reached at: tcp/10.0.123.45:45215

      11:12:16.166 [info] [zenoh::net::runtime::orchestrator] zenohd listening scout messages on 224.0.0.224:7446
      {:ok, #Reference<0.3207146932.3642621953.187320>}

  Zenohex itself also logs a warning when a `:fifo` channel (see the
  [Configuration](readme.html#configuration) section in the README) becomes full, or when a
  `:ring` channel drops a sample:

      iex> :ok = Zenohex.Nif.Logger.enable()
      iex> :ok = Zenohex.Nif.Logger.set_level(:warning)

      11:12:16.162 [warning] [zenohex_nif::helper::forwarder] zenohex_nif: fifo channel is full, Zenoh's callback thread is blocked until it drains

  Note that the logger's default target is `"zenohex_nif"` (see `get_target/0`), so these
  warnings are visible even without calling `set_target/1`. `set_target/1` matches by string
  prefix, and `"zenohex_nif"` happens to start with `"zenoh"`, so broadening the target to
  `"zenoh"` (as in the example above, to see Zenoh's own internal logs) still includes these
  warnings. Set the target back to `"zenohex_nif"` to see only Zenohex's own warnings, without
  Zenoh's own (noisier, at `:info`) internal logs:

      iex> :ok = Zenohex.Nif.Logger.set_target("zenohex_nif")
  """

  @type level :: :error | :warning | :info | :debug

  @doc false
  defdelegate init(pid, level \\ :debug), to: Zenohex.Nif, as: :nif_logger_init

  @doc """
  Enables the native logger.

  Once enabled, log messages from the NIF layer will be forwarded
  to Elixir's `Logger`.

  By default, logging is disabled.
  """
  defdelegate enable(), to: Zenohex.Nif, as: :nif_logger_enable

  @doc """
  Disables the native logger.

  Stops forwarding log messages from the NIF layer to Elixir's `Logger`.
  """
  defdelegate disable(), to: Zenohex.Nif, as: :nif_logger_disable

  @doc """
  Retrieves the current logger target (i.e., module path).

  The target is a Rust's module path string within the NIF layer.

  By default, the target is `"zenohex_nif"`.
  """
  @spec get_target() :: String.t()
  defdelegate get_target(), to: Zenohex.Nif, as: :nif_logger_get_target

  @doc """
  Sets the logger target (i.e., module path).

  This value is used for filtering logging.

  ## Examples

  Setting the target to `"zenoh"` enables all log messages coming from the Zenoh.

      iex> Zenohex.Nif.Logger.set_target("zenoh")
  """
  @spec set_target(String.t()) :: :ok
  defdelegate set_target(target), to: Zenohex.Nif, as: :nif_logger_set_target

  @doc """
  Retrieves the current log level.

  The log level controls which messages are emitted from the NIF layer
  and forwarded to Elixir's `Logger`.
  """
  @spec get_level() :: {:ok, level()}
  defdelegate get_level(), to: Zenohex.Nif, as: :nif_logger_get_level

  @doc """
  Sets the log level.

  Adjusts the verbosity of the NIF logger. Accepts atoms like
  `:error`, `:warning`, `:info`, or `:debug`. Messages at this level
  or higher will be forwarded to Elixir's `Logger`.

  By default, the level is `:debug`.

  ## Examples

      iex> Zenohex.Nif.Logger.set_level(:info)
  """
  @spec set_level(level :: level()) :: :ok
  defdelegate set_level(level), to: Zenohex.Nif, as: :nif_logger_set_level
end
