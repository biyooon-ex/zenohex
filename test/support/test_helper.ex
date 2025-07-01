defmodule Zenohex.Test.Support.TestHelper do
  @spec scouting_delay(binary(), non_neg_integer()) :: binary()
  def scouting_delay(config, delay) when is_integer(delay) and delay >= 0 do
    Zenohex.Config.update_in(config, ["scouting", "delay"], fn _ -> delay end)
  end

  def mode(config, mode) when mode in ["peer", "client"] do
    Zenohex.Config.update_in(config, ["mode"], fn _ -> mode end)
  end
end
