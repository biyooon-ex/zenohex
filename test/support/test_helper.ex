defmodule Zenohex.Test.Support.TestHelper do
  @moduledoc false

  @spec scouting_delay(binary(), non_neg_integer()) :: binary()
  def scouting_delay(config, delay) when is_integer(delay) and delay >= 0 do
    {:ok, updated_config} =
      Zenohex.Config.insert_json5(config, "scouting/delay", Integer.to_string(delay))

    updated_config
  end

  def mode(config, mode) when mode in ["peer", "client"] do
    {:ok, updated_config} =
      Zenohex.Config.insert_json5(config, "mode", ~s("#{mode}"))

    updated_config
  end
end
