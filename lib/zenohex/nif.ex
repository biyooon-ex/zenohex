defmodule Zenohex.Nif do
  @moduledoc false

  @type id :: reference()
  @type zenoh_query :: reference()
  @type nif_logger_level :: :debug | :info | :warning | :error

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

  @spec session_put(id(), String.t(), binary(), keyword()) :: :ok | {:error, reason :: term()}
  def session_put(_session_id, _key_expr, _payload, _opts), do: err()

  @spec session_delete(id(), String.t(), keyword()) :: :ok | {:error, reason :: term()}
  def session_delete(_session_id, _key_expr, _opts), do: err()

  @spec session_get(id(), String.t(), non_neg_integer(), keyword()) ::
          {:ok, [Zenohex.Sample.t() | Zenohex.Query.ReplyError.t()]}
          | {:error, :timeout}
          | {:error, term()}
  def session_get(_session_id, _selector, _timeout, _opts), do: err()

  @spec session_new_timestamp(id()) :: {:ok, String.t()} | {:error, term()}
  def session_new_timestamp(_session_id), do: err()

  @spec session_info(id()) :: {:ok, Zenohex.Session.Info.t()}
  def session_info(_session_id), do: err()

  # NOTE: Not supported in Zenohex.
  #       Use publisher instead, which is sufficient for all use cases.
  # @spec session_declare_keyexpr(id(), String.t()) ::
  #         {:ok, reference()} | {:error, reason :: term()}
  # def session_declare_keyexpr(_session_id, _key_expr), do: err()

  @spec session_declare_publisher(id(), String.t(), keyword()) ::
          {:ok, publisher_id :: id()} | {:error, reason :: term()}
  def session_declare_publisher(_session_id, _key_expr, _opts), do: err()

  @spec session_declare_subscriber(id(), String.t(), pid(), keyword()) ::
          {:ok, subscriber_id :: id()}
  def session_declare_subscriber(_session_id, _key_expr, _pid, _opts), do: err()

  @spec session_declare_queryable(id(), String.t(), pid(), keyword()) ::
          {:ok, queryable_id :: id()}
  def session_declare_queryable(_session_id, _key_expr, _pid, _opts), do: err()

  # Publisher

  @spec publisher_undeclare(id()) :: :ok | {:error, reason :: term()}
  def publisher_undeclare(_publisher_id), do: err()

  @spec publisher_put(id(), binary()) :: :ok | {:error, reason :: term()}
  def publisher_put(_publisher_id, _payload), do: err()

  @spec publisher_delete(id()) :: :ok | {:error, reason :: term()}
  def publisher_delete(_publisher_id), do: err()

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

  @spec query_reply_delete(zenoh_query(), String.t(), keyword()) ::
          :ok | {:error, reason :: term()}
  def query_reply_delete(_zenoh_query, _key_expr, _opts), do: err()

  # KeyExpr

  # NOTE: Not supported in Zenohex.
  #       Use publisher instead, which is sufficient for all use cases.
  # @spec keyexpr_undeclare(id(), key_expr :: reference()) :: :ok | {:error, term()}
  # def keyexpr_undeclare(_session_id, _key_expr), do: err()

  @spec keyexpr_autocanonize(String.t()) :: String.t()
  def keyexpr_autocanonize(_key_expr), do: err()

  @spec keyexpr_valid?(String.t()) :: boolean()
  def keyexpr_valid?(_key_expr), do: err()

  @spec keyexpr_intersects?(String.t(), String.t()) :: boolean()
  def keyexpr_intersects?(_key_expr1, _keyexpr2), do: err()

  @spec keyexpr_includes?(String.t(), String.t()) :: boolean()
  def keyexpr_includes?(_key_expr1, _keyexpr2), do: err()

  # Liveliness
  @spec liveliness_get(id(), String.t(), non_neg_integer()) ::
          {:ok, [Zenohex.Sample.t() | Zenohex.Query.ReplyError.t()]}
          | {:error, :timeout}
          | {:error, term()}
  def liveliness_get(_session_id, _key_expr, _timeout), do: err()

  @spec liveliness_declare_subscriber(id(), String.t(), pid(), keyword()) ::
          {:ok, subscriber_id :: id()}
  def liveliness_declare_subscriber(_session_id, _key_expr, _pid, _opts \\ []), do: err()

  @spec liveliness_declare_token(id(), String.t()) ::
          {:ok, liveliness_token :: reference()} | {:error, term()}
  def liveliness_declare_token(_session_id, _key_expr), do: err()

  @spec liveliness_token_undeclare(liveliness_token :: reference()) :: :ok | {:error, term()}
  def liveliness_token_undeclare(_token), do: err()

  # Scouting
  def scouting_scout(_what, _json5_binary, _timeout), do: err()
  def scouting_declare_scout(_what, _json5_binary, _pid), do: err()
  def scouting_stop_scout(_scout), do: err()

  # Config

  def config_default(), do: err()
  def config_from_json5(_binary), do: err()

  # Logger

  @spec nif_logger_init(pid(), nif_logger_level()) :: :ok
  def nif_logger_init(_pid, _level), do: err()

  @spec nif_logger_enable() :: :ok
  def nif_logger_enable(), do: err()

  @spec nif_logger_disable() :: :ok
  def nif_logger_disable(), do: err()

  @spec nif_logger_get_target() :: String.t()
  def nif_logger_get_target(), do: err()

  @spec nif_logger_set_target(String.t()) :: :ok
  def nif_logger_set_target(_target), do: err()

  @spec nif_logger_get_level() :: {:ok, nif_logger_level()}
  def nif_logger_get_level(), do: err()

  @spec nif_logger_set_level(nif_logger_level()) :: :ok
  def nif_logger_set_level(_level), do: err()

  # This function is for testing purposes only.
  @spec nif_logger_log(nif_logger_level(), String.t()) :: :ok
  def nif_logger_log(_level, _message), do: err()

  # Helper

  def keyword_get_value(_keyword, _key), do: err()
end
