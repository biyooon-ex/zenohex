defmodule Zenohex.Hello do
  @type t :: %__MODULE__{
          locators: String.t(),
          whatami: :peer | :router,
          zid: String.t()
        }

  defstruct [
    :locators,
    :whatami,
    :zid
  ]
end
