defmodule NifZenoh do
  use Rustler, otp_app: :zenohex, crate: :nifzenoh
  def call_sub_zenoh(), do: exit(:nif_not_loaded)
  def call_pub_zenoh(), do: exit(:nif_not_loaded)
end
