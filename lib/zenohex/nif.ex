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
    targets:
      RustlerPrecompiled.Config.default_targets()
      |> Enum.reject(&(&1 == "riscv64gc-unknown-linux-gnu"))

  # for Nerves
  @compile {:autoload, false}
  # suppress dialyzer error, remove this when https://github.com/rusterlium/rustler/pull/570 is released
  @dialyzer :no_match

  alias Zenohex.Publisher
  alias Zenohex.Subscriber
  alias Zenohex.Queryable
  alias Zenohex.Query
  alias Zenohex.Config

  defp err(), do: :erlang.nif_error(:nif_not_loaded)

  def zenoh_open(_config \\ %Config{}), do: err()

  for type <- ["integer", "float", "binary"] do
    def unquote(:"session_put_#{type}")(_session, _key_expr, _value), do: err()
  end

  def session_get_reply_receiver(_session, _selector, _opts \\ %Query.Options{}), do: err()

  def session_get_reply_timeout(_receiver, _timeout_us), do: err()

  def session_delete(_session, _key_expr), do: err()

  def declare_publisher(_session, _key_expr, _opts \\ %Publisher.Options{}), do: err()

  for type <- ["integer", "float", "binary"] do
    def unquote(:"publisher_put_#{type}")(_publisher, _value), do: err()
  end

  def publisher_delete(_publisher), do: err()

  def publisher_congestion_control(_publisher, _congestion_control), do: err()

  def publisher_priority(_publisher, _priority), do: err()

  def declare_subscriber(_session, _key_expr, _opts \\ %Subscriber.Options{}), do: err()

  def subscriber_recv_timeout(_subscriber, _timeout_us), do: err()

  def declare_pull_subscriber(_session, _key_expr, _opts \\ %Subscriber.Options{}), do: err()

  def pull_subscriber_pull(_pull_subscriber), do: err()

  def pull_subscriber_recv_timeout(_pull_subscriber, _timeout_us), do: err()

  def declare_queryable(_session, _key_expr, _opts \\ %Queryable.Options{}), do: err()

  def queryable_recv_timeout(_queryable, _timeout_us), do: err()

  def query_reply(_query, _sample), do: err()

  def query_finish_reply(_query), do: err()

  def key_expr_intersects(_key_expr1, _key_expr2), do: err()
end
