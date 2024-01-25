defmodule Zenohex.Publisher do
  alias Zenohex.Nif

  @type t :: reference()
  @type congestion_control :: :drop | :block
  @type priority ::
          :real_time
          | :interactive_high
          | :interactive_low
          | :data_high
          | :data
          | :data_low
          | :background

  defmodule Options do
    defstruct congestion_control: :drop, priority: :data
  end

  @spec put!(t(), binary()) :: :ok
  def put!(publisher, value) when is_binary(value) do
    Nif.publisher_put_binary(publisher, value)
  end

  @spec put!(t(), integer()) :: :ok
  def put!(publisher, value) when is_integer(value) do
    Nif.publisher_put_integer(publisher, value)
  end

  @spec put!(t(), float()) :: :ok
  def put!(publisher, value) when is_float(value) do
    Nif.publisher_put_float(publisher, value)
  end

  @spec delete!(t()) :: :ok
  def delete!(publisher) do
    Nif.publisher_delete(publisher)
  end

  @spec congestion_control!(t(), congestion_control()) :: t()
  def congestion_control!(publisher, congestion_control) do
    Nif.publisher_congestion_control(publisher, congestion_control)
  end

  @spec priority!(t(), priority()) :: t()
  def priority!(publisher, priority) do
    Nif.publisher_priority(publisher, priority)
  end
end
