defmodule Publisher do
  @spec put(NifZenoh.publisher(), any) :: none
  def put(publisher, value) do
    cond do
      is_binary(value) -> NifZenoh.publisher_put_string(publisher, value)
      is_float(value) -> NifZenoh.publisher_put_float(publisher, value)
      is_integer(value) -> NifZenoh.publisher_put_integer(publisher, value)
      true -> :error
    end
  end
end
