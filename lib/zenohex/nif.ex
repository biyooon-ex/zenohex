defmodule Zenohex.Nif do
  @moduledoc false

  mix_config = Mix.Project.config()
  version = mix_config[:version]
  github_url = mix_config[:package][:links]["GitHub"]

  use RustlerPrecompiled,
    # NOTE: FROM HERE Rustler opts which are passed through to Rustler
    otp_app: :zenohex,
    crate: "zenohex_nif",
    # NOTE: Uncomment during zenohhex_nif development.
    #       Setting `mode: :debug` makes `cargo build` skip the `--release` flag.
    # mode: :debug,
    # NOTE: FROM HERE RustlerPrecompiled opts
    version: version,
    base_url: "#{github_url}/releases/download/v#{version}",
    targets:
      RustlerPrecompiled.Config.default_targets()
      |> Enum.reject(&(&1 == "riscv64gc-unknown-linux-gnu"))

  # for Nerves
  @compile {:autoload, false}

  defp err(), do: :erlang.nif_error(:nif_not_loaded)

  def session_open(_json5_binary), do: err()
  def session_close(_session_id), do: err()
  def session_put(_session_id, _key_expr, _payload, _encoding), do: err()
  def session_get(_session_id, _selector, _timeout), do: err()
  def session_declare_publisher(_session_id, _key_expr, _encoding), do: err()
  def session_declare_subscriber(_session_id, _key_expr, _pid), do: err()
  def session_declare_queryable(_session_id, _key_expr, _pid), do: err()

  def config_default(), do: err()
  def config_from_json5(_binary), do: err()

  def publisher_put(_publisher_id, _payload), do: err()

  def query_reply(_zenohex_query), do: err()
end
