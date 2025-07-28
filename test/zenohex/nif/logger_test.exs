defmodule Zenohex.Nif.LoggerTest do
  use ExUnit.Case

  setup do
    :ok = Zenohex.Nif.nif_logger_init(self(), :debug)
    :ok
  end

  test "enable/0" do
    assert Zenohex.Nif.Logger.enable() == :ok

    :ok = Zenohex.Nif.nif_logger_log(:error, "message")

    assert_receive {:error, message}
    assert message =~ "message"
  end

  test "disable/0" do
    assert Zenohex.Nif.Logger.disable() == :ok

    :ok = Zenohex.Nif.nif_logger_log(:error, "message")

    refute_receive {:error, _message}
  end

  test "set_target/1, get_target/0" do
    assert Zenohex.Nif.Logger.set_target("zenohex_nif") == :ok
    assert Zenohex.Nif.Logger.get_target() == {:ok, "zenohex_nif"}
    assert Zenohex.Nif.Logger.set_target("zenoh")
    assert Zenohex.Nif.Logger.get_target() == {:ok, "zenoh"}
  end

  test "set_level/1, get_level/0" do
    assert Zenohex.Nif.Logger.set_level(:error) == :ok
    assert Zenohex.Nif.Logger.get_level() == {:ok, :error}

    # Confirm level filter works
    :ok = Zenohex.Nif.nif_logger_log(:warning, "message")
    refute_receive {:warning, _message}
  end
end
