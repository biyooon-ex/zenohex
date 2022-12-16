defmodule Session do
  def declare_publisher(session, key) do
    NifZenoh.session_declare_publisher(session, key)
  end
end
