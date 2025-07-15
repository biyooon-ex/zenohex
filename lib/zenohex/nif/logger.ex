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
