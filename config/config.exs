import Config

config :rustler_precompiled, :force_build, zenohex: true

# CI optimization for GitHub Actions workflows:
# skip Rustler compilation during `mix compile` if a cached NIF has been restored.
config :zenohex, Zenohex.Nif,
  skip_compilation?: System.get_env("GHA_SKIP_ZENOHEX_NIF_BUILD") in ["1", "true"]

import_config "#{config_env()}.exs"
