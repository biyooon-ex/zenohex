defmodule Zenohex.Nif do
  use Rustler, otp_app: :zenohex, crate: "zenohex_nif"

  # When your NIF is loaded, it will override this function.
  def add(_a, _b), do: :erlang.nif_error(:nif_not_loaded)

  def test_thread() do
    :erlang.nif_error(:nif_not_loaded)
  end

  def zenoh_open() do
    :erlang.nif_error(:nif_not_loaded)
  end

  def declare_publisher(_session, _key_expr) do
    :erlang.nif_error(:nif_not_loaded)
  end

  for type <- ["string", "integer", "float", "binary"] do
    def unquote(:"publisher_put_#{type}")(_publisher, _value) do
      :erlang.nif_error(:nif_not_loaded)
    end
  end

  def declare_subscriber(_session, _key_expr) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def subscriber_recv_timeout(_subscriber, _timeout_us) do
    :erlang.nif_error(:nif_not_loaded)
  end
end
