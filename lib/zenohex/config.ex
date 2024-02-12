defmodule Zenohex.Config do
  @moduledoc """
  Documentation for `#{__MODULE__}`.

  Used by `Zenohex.open/1`, `Zenohex.open!/1`.
  """

  alias Zenohex.Config.Connect
  alias Zenohex.Config.Scouting

  @type t :: %__MODULE__{connect: Connect.t(), scouting: Scouting.t()}
  defstruct connect: %Connect{}, scouting: %Scouting{}
end
