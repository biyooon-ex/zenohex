import Config

config :rustler_precompiled, :force_build, zenohex: true

import_config "#{config_env()}.exs"
