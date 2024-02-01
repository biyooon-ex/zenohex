defmodule Zenohex.Query do
  @moduledoc """
  Documentation for `#{__MODULE__}`.
  """

  @type t :: reference()

  defmodule Options do
    @moduledoc """
    Documentation for `#{__MODULE__}`.
    """

    @type t :: %__MODULE__{target: target(), consolidation: consolidation()}
    @type target :: :best_matching | :all | :all_complete
    @type consolidation :: :auto | :none | :monotonic | :latest
    defstruct target: :best_matching, consolidation: :auto
  end
end
