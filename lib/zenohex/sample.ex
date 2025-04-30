defmodule Zenohex.Sample do
  @zenoh_default_encoding "zenoh/bytes"

  @type t :: %__MODULE__{
          key_expr: String.t(),
          payload: binary(),
          encoding: String.t()
        }
  defstruct key_expr: "key/expr", payload: "payload", encoding: @zenoh_default_encoding
end
