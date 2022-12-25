defmodule NifZenoh do
  use Rustler, otp_app: :zenohex, crate: :nifzenoh

  @type session() :: reference()
  @type publisher() :: reference()

  @spec zenoh_open :: session() | no_return()
  def zenoh_open(), do: :erlang.nif_error("NIF zenoh_open is not implemented")

  @spec session_declare_publisher(session(), charlist()) :: {:ok, publisher()}
  def session_declare_publisher(_session, _keyexpr),
    do: :erlang.nif_error("NIF session_declare_publisher is not implemented")

  @spec publisher_put(publisher(), charlist()) :: no_return()
  def publisher_put(_publisher, _value),
    do: :erlang.nif_error("NIF publisher_put is not implemented")

  @spec tester_pub(charlist(), charlist()) :: no_return()
  def tester_pub(_keyexpr, _value), do: :erlang.nif_error("NIF tester_pub is not implemented")

  @spec tester_sub(charlist()) :: no_return()
  def tester_sub(_keyexpr), do: :erlang.nif_error("NIF tester_sub is not implemented")

  @spec session_declare_subscriber(session(), charlist(), pid()) :: no_return()
  def session_declare_subscriber(_session, _keyexpr, _callbackpid),
    do: :erlang.nif_error("NIF session_declare_subscriber is not implemented")

  @spec session_declare_subscriber_wrapper(session(), charlist(), function()) :: no_return()
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
