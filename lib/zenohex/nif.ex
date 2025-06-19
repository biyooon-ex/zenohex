defmodule Zenohex.Nif do
  @moduledoc false

  @type id :: reference()
  @type zenoh_query :: reference()

  mix_config = Mix.Project.config()
  version = mix_config[:version]
  github_url = mix_config[:package][:links]["GitHub"]

  use RustlerPrecompiled,
    # NOTE: FROM HERE Rustler opts which are passed through to Rustler
    otp_app: :zenohex,
    crate: "zenohex_nif",
    # NOTE: Uncomment during zenohhex_nif development.
    #       Setting `mode: :debug` makes `cargo build` skip the `--release` flag.
    #       TODO: Comment out before release.
    mode: :debug,
    # NOTE: FROM HERE RustlerPrecompiled opts
    version: version,
    base_url: "#{github_url}/releases/download/v#{version}",
    targets:
      RustlerPrecompiled.Config.default_targets()
      |> Enum.reject(&(&1 == "riscv64gc-unknown-linux-gnu"))

  # for Nerves
  @compile {:autoload, false}

  defp err(), do: :erlang.nif_error(:nif_not_loaded)

  # Session

  @spec session_open(binary()) :: {:ok, id()} | {:error, reason :: term()}
  def session_open(_json5_binary), do: err()

  @spec session_close(id()) :: :ok | {:error, reason :: term()}
  def session_close(_session_id), do: err()

  @spec session_put(id(), String.t(), String.t(), keyword()) :: :ok | {:error, reason :: term()}
  def session_put(_session_id, _key_expr, _payload, _opts), do: err()

  @spec session_get(id(), String.t(), non_neg_integer()) ::
          {:ok, [Zenohex.Sample.t() | Zenohex.Query.ReplyError.t()]}
          | {:error, :timeout}
          | {:error, term()}
  def session_get(_session_id, _selector, _timeout), do: err()

  @spec session_declare_publisher(id(), String.t(), keyword()) ::
          {:ok, publisher_id :: id()} | {:error, reason :: term()}
  def session_declare_publisher(_session_id, _key_expr, _opts), do: err()

  @spec session_declare_subscriber(id(), String.t(), pid()) :: {:ok, subscriber_id :: id()}
  def session_declare_subscriber(_session_id, _key_expr, _pid), do: err()

  @spec session_declare_queryable(id(), String.t(), pid()) :: {:ok, queryable_id :: id()}
  def session_declare_queryable(_session_id, _key_expr, _pid), do: err()

  # Publisher

  @spec publisher_undeclare(id()) :: :ok | {:error, reason :: term()}
  def publisher_undeclare(_publisher_id), do: err()

  @spec publisher_put(id(), binary()) :: :ok | {:error, reason :: term()}
  def publisher_put(_publisher_id, _payload), do: err()

  # Subscriber

  @spec subscriber_undeclare(id()) :: :ok | {:error, reason :: term()}
  def subscriber_undeclare(_subscriber_id), do: err()

  # Queryable

  @spec queryable_undeclare(id()) :: :ok | {:error, reason :: term()}
  def queryable_undeclare(_queryable_id), do: err()

  # Query

  @spec query_reply(zenoh_query(), String.t(), binary(), keyword()) ::
          :ok | {:error, reason :: term()}
  def query_reply(_zenoh_query, _key_expr, _payload, _opts), do: err()

  @spec query_reply_error(zenoh_query(), binary(), keyword()) ::
          :ok | {:error, reason :: term()}
  def query_reply_error(_zenoh_query, _payload, _opts), do: err()

  # Config

  def config_default(), do: err()
  def config_from_json5(_binary), do: err()
end
