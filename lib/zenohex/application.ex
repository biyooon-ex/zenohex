defmodule Zenohex.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children =
      [] ++ nif_logger(Application.get_env(:zenohex, :nif_logger, []))

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  def nif_logger(configs) when is_list(configs) do
    if Keyword.get(configs, :enable, true) do
      [{Zenohex.Nif.Logger.Supervisor, []}]
    else
      []
    end
  end
end
