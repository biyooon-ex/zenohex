defmodule Publisher do
  def put(publisher, value) do
    NifZenoh.publisher_put(publisher, value)
  end
end
