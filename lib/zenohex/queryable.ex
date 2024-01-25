defmodule Zenohex.Queryable do
  @type t :: reference()
  @type complete :: boolean()

  defmodule Options do
    defstruct complete: false
  end
end
