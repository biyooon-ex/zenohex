defmodule Zenohex.Query do
  @type t :: %__MODULE__{
          selector: String.t(),
          key_expr: String.t(),
          parameters: String.t(),
          payload: binary(),
          encoding: String.t(),
          zenoh_query: Zenohex.Nif.zenoh_query()
        }

  defstruct selector: "key/expr",
            key_expr: "key/expr",
            parameters: "",
            payload: nil,
            encoding: nil,
            zenoh_query: nil

  defmodule ReplyError do
    @zenoh_default_encoding "zenoh/bytes"

    @type t :: %__MODULE__{
            payload: binary(),
            encoding: String.t()
          }
    defstruct payload: "payload", encoding: @zenoh_default_encoding
  end

  defdelegate reply(zenoh_query, key_expr, payload, opts \\ [final?: true]),
    to: Zenohex.Nif,
    as: :query_reply

  defdelegate reply_error(zenoh_query, payload, opts \\ [final?: true]),
    to: Zenohex.Nif,
    as: :query_reply_error
end
