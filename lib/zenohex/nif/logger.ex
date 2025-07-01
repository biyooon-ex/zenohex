defmodule Zenohex.Nif.Logger do
  defdelegate init(pid), to: Zenohex.Nif, as: :nif_logger_init
  defdelegate enable(), to: Zenohex.Nif, as: :nif_logger_enable
  defdelegate disable(), to: Zenohex.Nif, as: :nif_logger_disable
  defdelegate get_target(), to: Zenohex.Nif, as: :nif_logger_get_target
  defdelegate set_target(target), to: Zenohex.Nif, as: :nif_logger_set_target
  defdelegate get_level(), to: Zenohex.Nif, as: :nif_logger_get_level
  defdelegate set_level(level), to: Zenohex.Nif, as: :nif_logger_set_level
end
