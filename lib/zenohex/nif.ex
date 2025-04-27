defmodule Zenohex.Nif do
  @moduledoc false

  mix_config = Mix.Project.config()
  version = mix_config[:version]
  github_url = mix_config[:package][:links]["GitHub"]

  use RustlerPrecompiled,
    otp_app: :zenohex,
    crate: "zenohex_nif",
    version: version,
    base_url: "#{github_url}/releases/download/v#{version}",
    # NOTE: Uncomment during zenohhex_nif development.
    #       Setting `mode: :debug` makes `cargo build` skip the `--release` flag.
    # mode: :debug,
    targets:
      RustlerPrecompiled.Config.default_targets()
      |> Enum.reject(&(&1 == "riscv64gc-unknown-linux-gnu"))

  # for Nerves
  @compile {:autoload, false}

  defp err(), do: :erlang.nif_error(:nif_not_loaded)

  def session_open(_json5_binary), do: err()
  def session_close(_session_id), do: err()
  def session_put(_session_id, _key_expr, _payload), do: err()
  def session_declare_publisher(_session_id, _key_expr), do: err()

  def config_default(), do: err()
  def config_from_json5(_binary), do: err()

  def publisher_put(_publisher_id, _payload), do: err()
end
