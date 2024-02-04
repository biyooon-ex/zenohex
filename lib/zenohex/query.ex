defmodule Zenohex.Query do
  @moduledoc """
  Documentation for `#{__MODULE__}`.
  """

  alias Zenohex.Nif
  alias Zenohex.Sample

  @type t :: %__MODULE__{
          key_expr: String.t(),
          parameters: String.t(),
          value: binary() | integer() | float() | :undefined,
          reference: reference()
        }
  defstruct [:key_expr, :parameters, :value, :reference]

  defmodule Options do
    @moduledoc """
    Documentation for `#{__MODULE__}`.
    """

    @type t :: %__MODULE__{target: target(), consolidation: consolidation()}
    @type target :: :best_matching | :all | :all_complete
    @type consolidation :: :auto | :none | :monotonic | :latest
    defstruct target: :best_matching, consolidation: :auto
  end

  @spec reply(t(), Sample.t()) :: :ok | {:error, reason :: String.t()}
  def reply(query, sample) when is_struct(query, __MODULE__) and is_struct(sample, Sample) do
    Nif.query_reply(query, sample)
  end
end
