import Config

config :rustler_precompiled, :force_build, zenohex: true

config :zenohex, Zenohex.Nif,
  skip_compilation?: System.get_env("SKIP_ZENOHEX_NIF_BUILD") in ["1", "true"]

import_config "#{config_env()}.exs"
