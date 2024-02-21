defmodule Zenohex.Config.Scouting do
  @moduledoc """
  Documentation for `#{__MODULE__}`.
  """

  @type t :: %__MODULE__{delay: delay()}

  @typedoc """
  In peer mode, the period dedicated to scouting remote peers before attempting other operations. In milliseconds.
  """
  @type delay :: non_neg_integer() | :undefined

  defstruct delay: :undefined
end
