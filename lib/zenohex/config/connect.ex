defmodule Zenohex.Config.Connect do
  @moduledoc """
  Documentation for `#{__MODULE__}`.
  """

  @type t :: %__MODULE__{endpoints: endpoints()}

  @typedoc """
  ex. ["tcp/192.168.1.1:7447", "tcp/192.168.1.2:7447"]
  """
  @type endpoints() :: [String.t()]

  defstruct endpoints: []
end
