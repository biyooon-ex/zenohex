defmodule Zenohex.Sample do
  @moduledoc """
  Documentation for `#{__MODULE__}`.
  """

  @type t :: %__MODULE__{
          key_expr: String.t(),
          value: binary() | integer() | float(),
          kind: :put | :delete
        }
  defstruct [:key_expr, :value, :kind]
end
