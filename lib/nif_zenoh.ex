defmodule NifZenoh do
  use Rustler, otp_app: :zenohex, crate: :nifzenoh
  def open(), do: exit(:nif_not_loaded)
  def nif_declare_publisher(_session, _keyexpr), do: exit(:nif_not_loaded)
  def nif_put(_publisher, _value), do: exit(:nif_not_loaded)
  def call_pub_zenoh(_keyexpr, _value), do: exit(:nif_not_loaded)
  def call_sub_zenoh(_keyexpr), do: exit(:nif_not_loaded)
end
