defmodule Zenohex.Sample do
  @zenoh_default_encoding "zenoh/bytes"

  @type t :: %__MODULE__{
          encoding: String.t(),
          key_expr: String.t(),
          kind: :put | :delete,
          payload: binary()
        }
  defstruct encoding: @zenoh_default_encoding,
            key_expr: "key/expr",
            kind: :put,
            payload: "payload"
end
