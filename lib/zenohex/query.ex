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

  @doc ~S"""
  Sends a reply to this Query. User can call `reply/2` multiple times to send multiple samples.

  > ### Warning {: .warning}
  > Do not forget to call `finish_reply/1` to finish the reply.
  """
  @spec reply(t(), Sample.t()) :: :ok | {:error, reason :: any()}
  def reply(query, sample) when is_struct(query, __MODULE__) and is_struct(sample, Sample) do
    Nif.query_reply(query, sample)
  end

  @doc ~S"""
  Finish reply.

  > ### Warning {: .warning}
  > `finish_reply/1` must be called after `reply/2`.
  """
  @spec finish_reply(t()) :: :ok | {:error, reason :: any()}
  def finish_reply(query) when is_struct(query, __MODULE__) do
    Nif.query_finish_reply(query)
  end
end
