defmodule Zenohex.Publisher do
  @moduledoc """
  Documentation for `#{__MODULE__}`.
  """

  alias Zenohex.Nif

  @type t :: reference()

  defmodule Options do
    @moduledoc """
    Documentation for `#{__MODULE__}`.

    Used by `Zenohex.Session.declare_publisher/3`.
    """

    @type t :: %__MODULE__{congestion_control: congestion_control(), priority: priority()}
    @type congestion_control :: :drop | :block
    @type priority ::
            :real_time
            | :interactive_high
            | :interactive_low
            | :data_high
            | :data
            | :data_low
            | :background

    defstruct congestion_control: :drop, priority: :data
  end

  @doc ~S"""
  Put data.

  ## Examples

      iex> {:ok, session} = Zenohex.open()
      iex> {:ok, publisher} = Zenohex.Session.declare_publisher(session, "key/expression")
      iex> :ok = Zenohex.Publisher.put(publisher, "value")
      iex> :ok = Zenohex.Publisher.put(publisher, 0)
      iex> :ok = Zenohex.Publisher.put(publisher, 0.0)
  """
  @spec put(t(), binary() | integer() | float()) :: :ok | {:error, reason :: any()}
  def put(publisher, value) when is_binary(value) do
    Nif.publisher_put_binary(publisher, value)
  end

  def put(publisher, value) when is_integer(value) do
    Nif.publisher_put_integer(publisher, value)
  end

  def put(publisher, value) when is_float(value) do
    Nif.publisher_put_float(publisher, value)
  end

  @doc ~S"""
  Delete data.

  ## Examples

      iex> {:ok, session} = Zenohex.open()
      iex> {:ok, publisher} = Zenohex.Session.declare_publisher(session, "key/expression")
      iex> :ok = Zenohex.Publisher.delete(publisher)
  """
  @spec delete(t()) :: :ok | {:error, reason :: any()}
  def delete(publisher) do
    Nif.publisher_delete(publisher)
  end

  @doc ~S"""
  Change the congestion_control to apply when routing the data.

  ## Examples

      iex> {:ok, session} = Zenohex.open()
      iex> {:ok, publisher} = Zenohex.Session.declare_publisher(session, "key/expression")
      iex> Zenohex.Publisher.congestion_control(publisher, :drop)
  """
  @spec congestion_control(t(), Options.congestion_control()) :: t()
  def congestion_control(publisher, congestion_control) do
    Nif.publisher_congestion_control(publisher, congestion_control)
  end

  @doc ~S"""
  Change the priority of the written data.

  ## Examples

      iex> {:ok, session} = Zenohex.open()
      iex> {:ok, publisher} = Zenohex.Session.declare_publisher(session, "key/expression")
      iex> Zenohex.Publisher.priority(publisher, :real_time)
  """
  @spec priority(t(), Options.priority()) :: t()
  def priority(publisher, priority) do
    Nif.publisher_priority(publisher, priority)
  end
end
