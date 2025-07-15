defmodule Zenohex.Nif do
  @moduledoc false

  @type session_id :: reference()
  @type entity_id :: reference()
  @type query :: reference()
  @type scout :: reference()
  @type liveliness_token :: reference()
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

  @spec session_open(binary()) :: {:ok, session_id()} | {:error, term()}
  def session_open(_json5_binary), do: err()

  @spec session_close(session_id()) :: :ok | {:error, term()}
  def session_close(_session_id), do: err()

  @spec session_put(session_id(), String.t(), binary(), keyword()) ::
          :ok | {:error, term()}
  def session_put(_session_id, _key_expr, _payload, _opts), do: err()

  @spec session_delete(session_id(), String.t(), keyword()) :: :ok | {:error, term()}
  def session_delete(_session_id, _key_expr, _opts), do: err()

  @spec session_get(session_id(), String.t(), non_neg_integer(), keyword()) ::
          {:ok, [Zenohex.Sample.t() | Zenohex.Query.ReplyError.t()]}
          | {:error, :timeout}
          | {:error, term()}
  def session_get(_session_id, _selector, _timeout, _opts), do: err()

  @spec session_new_timestamp(session_id()) :: {:ok, String.t()} | {:error, term()}
  def session_new_timestamp(_session_id), do: err()

  @spec session_info(session_id()) :: {:ok, Zenohex.Session.Info.t()}
  def session_info(_session_id), do: err()

  # NOTE: Not supported in Zenohex.
  #       Use publisher instead, which is sufficient for all use cases.
  # @spec session_declare_keyexpr(id(), String.t()) ::
  #         {:ok, reference()} | {:error, term()}
  # def session_declare_keyexpr(_session_id, _key_expr), do: err()

  @spec session_declare_publisher(session_id(), String.t(), keyword()) ::
          {:ok, entity_id()} | {:error, term()}
  def session_declare_publisher(_session_id, _key_expr, _opts), do: err()

  @spec session_declare_subscriber(session_id(), String.t(), pid(), keyword()) ::
          {:ok, entity_id()}
  def session_declare_subscriber(_session_id, _key_expr, _pid, _opts), do: err()

  @spec session_declare_queryable(session_id(), String.t(), pid(), keyword()) ::
          {:ok, entity_id()}
  def session_declare_queryable(_session_id, _key_expr, _pid, _opts), do: err()

  # Publisher

  @spec publisher_undeclare(entity_id()) :: :ok | {:error, term()}
  def publisher_undeclare(_publisher_id), do: err()

  @spec publisher_put(entity_id(), binary()) :: :ok | {:error, term()}
  def publisher_put(_publisher_id, _payload), do: err()

  @spec publisher_delete(entity_id()) :: :ok | {:error, term()}
  def publisher_delete(_publisher_id), do: err()

  # Subscriber

  @spec subscriber_undeclare(entity_id()) :: :ok | {:error, term()}
  def subscriber_undeclare(_subscriber_id), do: err()

  # Queryable

  @spec queryable_undeclare(entity_id()) :: :ok | {:error, term()}
  def queryable_undeclare(_queryable_id), do: err()

  # Query

  @spec query_reply(query(), String.t(), binary(), keyword()) ::
          :ok | {:error, term()}
  def query_reply(_zenoh_query, _key_expr, _payload, _opts), do: err()

  @spec query_reply_error(query(), binary(), keyword()) ::
          :ok | {:error, term()}
  def query_reply_error(_zenoh_query, _payload, _opts), do: err()

  @spec query_reply_delete(query(), String.t(), keyword()) ::
          :ok | {:error, term()}
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

  @spec liveliness_get(session_id(), String.t(), non_neg_integer()) ::
          {:ok, [Zenohex.Sample.t() | Zenohex.Query.ReplyError.t()]}
          | {:error, :timeout}
          | {:error, term()}
  def liveliness_get(_session_id, _key_expr, _timeout), do: err()

  @spec liveliness_declare_subscriber(session_id(), String.t(), pid(), keyword()) ::
          {:ok, subscriber_id :: entity_id()}
  def liveliness_declare_subscriber(_session_id, _key_expr, _pid, _opts \\ []), do: err()

  @spec liveliness_declare_token(session_id(), String.t()) ::
          {:ok, liveliness_token()} | {:error, term()}
  def liveliness_declare_token(_session_id, _key_expr), do: err()

  @spec liveliness_token_undeclare(liveliness_token()) :: :ok | {:error, term()}
  def liveliness_token_undeclare(_token), do: err()

  # Scouting

  @spec scouting_scout(:peer | :router, String.t(), non_neg_integer()) ::
          {:ok, [Zenohex.Hello.t()]} | {:error, :timeout} | {:error, term()}
  def scouting_scout(_what, _json5_binary, _timeout), do: err()

  @spec scouting_declare_scout(:peer | :router, String.t(), pid()) ::
          {:ok, scout()} | {:error, term()}
  def scouting_declare_scout(_what, _json5_binary, _pid), do: err()

  @spec scouting_stop_scout(scout()) :: :ok | {:error, term()}
  def scouting_stop_scout(_scout), do: err()

  # Config

  @spec config_default() :: String.t()
  def config_default(), do: err()

  @spec config_from_json5(String.t()) :: {:ok, String.t()} | {:error, term()}
  def config_from_json5(_json5), do: err()

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

  @spec keyword_get_value(keyword(), atom()) :: term()
  def keyword_get_value(_keyword, _key), do: err()
end
