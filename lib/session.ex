defmodule Session do
  @spec declare_publisher(NifZenoh.session(), charlist()) :: {:ok, NifZenoh.publisher()}
  def declare_publisher(session, key) do
    NifZenoh.session_declare_publisher(session, key)
  end

  @spec declare_subscriber_wrapper(NifZenoh.session(), charlist(), function()) :: no_return()
  def declare_subscriber_wrapper(session, keyexpr, callback) do
    NifZenoh.session_declare_subscriber_wrapper(session, keyexpr, callback)
  end
end
