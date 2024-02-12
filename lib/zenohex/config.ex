defmodule Zenohex.Config do
  @moduledoc """
  Documentation for `#{__MODULE__}`.

  Used by `Zenohex.open/1`, `Zenohex.open!/1`.
  """

  alias Zenohex.Config.Scouting

  @type t :: %__MODULE__{scouting: Scouting.t()}
  defstruct scouting: %Scouting{}
end
