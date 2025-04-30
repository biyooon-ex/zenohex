defmodule Zenohex.Query do
  @zenoh_default_encoding "zenoh/bytes"

  @type t :: %__MODULE__{
          key_expr: String.t(),
          parameters: String.t(),
          payload: binary(),
          encoding: String.t(),
          zenoh_query: reference()
        }

  defstruct key_expr: "key/expr", parameters: "", payload: nil, encoding: nil, zenoh_query: nil

  defdelegate reply(query), to: Zenohex.Nif, as: :query_reply
end
