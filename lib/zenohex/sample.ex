defmodule Zenohex.Sample do
  @type t :: %__MODULE__{
          key_expr: String.t(),
          payload: binary()
        }
  defstruct key_expr: "key/expr", payload: <<>>
end
