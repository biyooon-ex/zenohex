defmodule Zenohex.ChannelConfig do
  @moduledoc false

  # WHY: read fresh from Application env on every call (not cached), so
  #      `config :zenohex, ...` changes (e.g. in tests) take effect without
  #      restarting the app; this is cheap (an ETS lookup), not a hot path.

  @valid_kinds [:fifo, :ring]
  @default_kind :fifo
  @default_capacity 256

  @type channel_kind :: :fifo | :ring
  @type t :: {channel_kind(), pos_integer()}

  @spec get() :: t()
  def get, do: {kind(), capacity()}

  defp kind do
    case Application.get_env(:zenohex, :channel_kind, @default_kind) do
      kind when kind in @valid_kinds ->
        kind

      other ->
        raise ArgumentError,
              "invalid :channel_kind #{inspect(other)} in config :zenohex, expected :fifo or :ring"
    end
  end

  defp capacity do
    case Application.get_env(:zenohex, :channel_capacity, @default_capacity) do
      capacity when is_integer(capacity) and capacity > 0 ->
        capacity

      other ->
        raise ArgumentError,
              "invalid :channel_capacity #{inspect(other)} in config :zenohex, expected a positive integer"
    end
  end
end
