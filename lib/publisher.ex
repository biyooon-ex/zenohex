defmodule Publisher do
  @spec put(NifZenoh.publisher(), any) :: none
  def put(publisher, value) do
    NifZenoh.publisher_put(publisher, value)
  end
end
