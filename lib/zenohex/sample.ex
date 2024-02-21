defmodule Zenohex.Sample do
  @moduledoc """
  Documentation for `#{__MODULE__}`.

  Structs received by

    * `Zenohex.Session.get_timeout/3` and `Zenohex.Session.get_reply_timeout/1`
    * `Zenohex.Subscriber.recv_timeout/1`
    * `Zenohex.PullSubscriber.recv_timeout/1`
  """

  @type t :: %__MODULE__{
          key_expr: String.t(),
          value: binary() | integer() | float(),
          kind: :put | :delete,
          reference: reference() | :undefined
        }
  defstruct key_expr: "", value: "", kind: :put, reference: :undefined
end
