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

  alias Zenohex.Publisher
  alias Zenohex.Subscriber
  alias Zenohex.Queryable
  alias Zenohex.Query

  def zenoh_open() do
    :erlang.nif_error(:nif_not_loaded)
  end

  def zenoh_scouting_delay_zero_session() do
    :erlang.nif_error(:nif_not_loaded)
  end

  for type <- ["integer", "float", "binary"] do
    def unquote(:"session_put_#{type}")(_session, _key_expr, _value) do
      :erlang.nif_error(:nif_not_loaded)
    end
  end

  def session_get_reply_receiver(_session, _selector, _opts \\ %Query.Options{}) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def session_get_reply_timeout(_receiver, _timeout_us) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def session_delete(_session, _key_expr) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def declare_publisher(_session, _key_expr, _opts \\ %Publisher.Options{}) do
    :erlang.nif_error(:nif_not_loaded)
  end

  for type <- ["integer", "float", "binary"] do
    def unquote(:"publisher_put_#{type}")(_publisher, _value) do
      :erlang.nif_error(:nif_not_loaded)
    end
  end

  def publisher_delete(_publisher) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def publisher_congestion_control(_publisher, _congestion_control) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def publisher_priority(_publisher, _priority) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def declare_subscriber(_session, _key_expr, _opts \\ %Subscriber.Options{}) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def subscriber_recv_timeout(_subscriber, _timeout_us) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def declare_pull_subscriber(_session, _key_expr, _opts \\ %Subscriber.Options{}) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def pull_subscriber_pull(_pull_subscriber) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def pull_subscriber_recv_timeout(_pull_subscriber, _timeout_us) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def declare_queryable(_session, _key_expr, _opts \\ %Queryable.Options{}) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def queryable_recv_timeout(_queryable, _timeout_us) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def query_reply(_query, _sample) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def query_finish_reply(_query) do
    :erlang.nif_error(:nif_not_loaded)
  end
end
