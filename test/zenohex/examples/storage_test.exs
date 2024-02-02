defmodule Zenohex.Examples.StorageTest do
  use ExUnit.Case

  alias Zenohex.Examples.Storage
  alias Zenohex.Session

  setup do
    {:ok, session} = Zenohex.open()
    start_supervised!({Storage, %{session: session, key_expr: "demo/example/**"}})

    %{session: session}
  end

  test "put", %{session: session} do
    key_expr = "demo/example/put"
    value = 0
    :ok = Session.put(session, key_expr, value)

    confirm_put(key_expr, value)
  end

  test "delete", %{session: session} do
    key_expr = "demo/example/delete"
    value = 0
    :ok = Session.put(session, key_expr, value)
    confirm_put(key_expr, value)

    :ok = Session.delete(session, key_expr)
    confirm_delete(key_expr)
  end

  defp confirm_put(key_expr, value, retry_count \\ 100) when retry_count > 0 do
    case Storage.Store.get(key_expr) do
      {:ok, [sample]} -> assert sample.value == value
      {:error, :not_found} -> confirm_put(key_expr, value, retry_count - 1)
    end
  end

  defp confirm_delete(key_expr, retry_count \\ 100) when retry_count > 0 do
    case Storage.Store.get(key_expr) do
      {:error, :not_found} -> assert true
      {:ok, [_sample]} -> confirm_delete(key_expr, retry_count - 1)
    end
  end
end
