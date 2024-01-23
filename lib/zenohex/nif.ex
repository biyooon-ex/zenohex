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

  for type <- ["integer", "float", "binary"] do
    def unquote(:"session_put_#{type}")(_session, _key_expr, _value) do
      :erlang.nif_error(:nif_not_loaded)
    end
  end

  def session_get_timeout(_session, _selector, _timeout_us) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def session_delete(_session, _key_expr) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def declare_publisher(_session, _key_expr, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  for type <- ["integer", "float", "binary"] do
    def unquote(:"publisher_put_#{type}")(_publisher, _value) do
      :erlang.nif_error(:nif_not_loaded)
    end
  end

  def publisher_delete(_publisher) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def publisher_congestion_control(_publisher, _congestion_control) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def publisher_priority(_publisher, _priority) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def declare_subscriber(_session, _key_expr, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def subscriber_recv_timeout(_subscriber, _timeout_us) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def declare_pull_subscriber(_session, _key_expr, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def pull_subscriber_pull(_pull_subscriber) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def pull_subscriber_recv_timeout(_pull_subscriber, _timeout_us) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def declare_queryable(_session, _key_expr, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end
end
