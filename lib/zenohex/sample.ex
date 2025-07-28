defmodule Zenohex.Sample do
  @moduledoc """
  A struct that corresponds one-to-one to `zenoh::sample::Sample`.

  see. https://docs.rs/zenoh/latest/zenoh/sample/struct.Sample.html
  """

  @zenoh_default_encoding "zenoh/bytes"

  @type t :: %__MODULE__{
          attachment: binary() | nil,
          congestion_control: Zenohex.Session.congestion_control(),
          encoding: String.t(),
          express: boolean(),
          key_expr: String.t(),
          kind: :put | :delete,
          payload: binary(),
          priority: Zenohex.Session.priority(),
          timestamp: Zenohex.Session.zenoh_timestamp_string() | nil
        }
  defstruct attachment: nil,
            congestion_control: :block,
            encoding: @zenoh_default_encoding,
            express: false,
            key_expr: "key/expr",
            kind: :put,
            payload: "payload",
            priority: :data,
            timestamp: nil
end
