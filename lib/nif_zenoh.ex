defmodule NifZenoh do
  use Rustler, otp_app: :zenohex, crate: :nifzenoh

  @spec zenoh_open :: {:ok, reference()}
  def zenoh_open(), do: exit(:nif_not_loaded)

  @spec session_declare_publisher(reference(), charlist()) :: {:ok, reference()}
  def session_declare_publisher(_session, _keyexpr), do: exit(:nif_not_loaded)

  @spec publisher_put(reference(), charlist()) :: no_return()
  def publisher_put(_publisher, _value), do: exit(:nif_not_loaded)

  @spec tester_pub(charlist(), charlist()) :: no_return()
  def tester_pub(_keyexpr, _value), do: exit(:nif_not_loaded)

  @spec tester_sub(charlist()) :: no_return()
  def tester_sub(_keyexpr), do: exit(:nif_not_loaded)

  @spec session_declare_subscriber(reference(), charlist(), pid()) :: none
  def session_declare_subscriber(_session, _keyexpr, _callbackpid), do: exit(:nif_not_loaded)

  @spec session_declare_subscriber_wrapper(reference(), charlist(), function()) :: no_return()
  def session_declare_subscriber_wrapper(session, keyexpr, callback) do
    pid =
      spawn(fn ->
        receive do
          msg -> callback.(msg)
        end
      end)

    session_declare_subscriber(session, keyexpr, pid)
  end
end
