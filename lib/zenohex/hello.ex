defmodule Zenohex.Hello do
  @moduledoc """
  A struct that corresponds one-to-one to `zenoh::scouting::Hello`.

  see. https://docs.rs/zenoh/latest/zenoh/scouting/struct.Hello.html

  ## Examples

      iex> Zenohex.scout(:peer, Zenohex.Config.default(), 100)
      {:ok,
       [
         %Zenohex.Hello{
           locators: ["tcp/[fe80::dead:beaf:cafe:1234]:36319",
            "tcp/10.0.123.45:36319"],
           whatami: :peer,
           zid: "de7815fc98e0bdbb69e84ff9653ee26"
         }
       ]}
  """

  @type t :: %__MODULE__{
          locators: [String.t()],
          whatami: :peer | :router,
          zid: Zenohex.Session.zid()
        }

  defstruct [
    :locators,
    :whatami,
    :zid
  ]
end
