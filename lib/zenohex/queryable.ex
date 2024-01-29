defmodule Zenohex.Queryable do
  @moduledoc """
  Documentation for `#{__MODULE__}`.
  """

  @type t :: reference()

  defmodule Options do
    @moduledoc """
    Documentation for `#{__MODULE__}`.
    """

    @type t :: %__MODULE__{complete: complete()}
    @type complete :: boolean()
    defstruct complete: false
  end
end
