defmodule Zenohex.Examples.Querier do
  @moduledoc """
  Example `GenServer` implementation of `Querier`
  using `Zenohex.Session.declare_querier/3`.

  This example demonstrates how to reuse a declared querier for multiple queries.

  For the actual implementation, please refer to the following,

  - #{Zenohex.MixProject.project()[:source_url]}/tree/main/#{Path.relative_to_cwd(__ENV__.file)}

  ## Examples

  Assumes a matching queryable is already running and replies on `key/expr/**`.

      iex> {:ok, session_id} = Zenohex.Session.open()
      iex> {:ok, _querier_pid} =
      ...>   Zenohex.Examples.Querier.start_link(
      ...>     session_id: session_id,
      ...>     key_expr: "key/expr/**"
      ...>   )
      iex> Zenohex.Examples.Querier.get(timeout: 1_000)
      {:ok, [%Zenohex.Sample{key_expr: "key/expr/1", payload: "reply"}]}
  """

  use GenServer

  @default_timeout 1_000

  @type get_opts :: [
          timeout: non_neg_integer(),
          attachment: binary() | nil,
          encoding: String.t(),
          parameters: String.t(),
          payload: binary() | nil
        ]

  @doc """
  Executes a query with the declared querier.

  The timeout used here controls how long the Elixir side waits while collecting
  replies. To configure the network-side query timeout, pass `query_timeout:` in
  `:querier_opts` when starting the server.
  """
  @spec get(get_opts()) ::
          {:ok, [Zenohex.Sample.t() | Zenohex.Query.ReplyError.t()]}
          | {:error, :timeout}
          | {:error, reason :: term()}
  def get(opts) when is_list(opts) do
    get(__MODULE__, opts)
  end

  @spec get(GenServer.server(), get_opts()) ::
          {:ok, [Zenohex.Sample.t() | Zenohex.Query.ReplyError.t()]}
          | {:error, :timeout}
          | {:error, reason :: term()}
  def get(name, opts \\ []) do
    querier_id = GenServer.call(name, :id)
    {timeout, querier_opts} = Keyword.pop(opts, :timeout, @default_timeout)
    Zenohex.Querier.get(querier_id, timeout, querier_opts)
  end

  @doc """
  Starts #{__MODULE__}.

  ## Parameters

    - `args` – a keyword list that can include the following keys:
      - `:session_id` – the ID of the session
      - `:key_expr` – the key expression to query
      - `:querier_opts` – options passed to `Zenohex.Session.declare_querier/3`
  """
  @spec start_link([
          {:session_id, Zenohex.Session.id()}
          | {:key_expr, String.t()}
          | {:name, GenServer.name()}
          | {:querier_opts, Zenohex.Session.querier_opts()}
        ]) :: GenServer.on_start()
  def start_link(args) do
    name = Keyword.get(args, :name, __MODULE__)
    GenServer.start_link(__MODULE__, args, name: name)
  end

  @doc """
  Stops #{__MODULE__}
  """
  @spec stop(GenServer.server()) :: :ok | {:error, reason :: term()}
  def stop(name \\ __MODULE__) do
    GenServer.call(name, :stop)
  end

  @doc false
  def child_spec(init_arg), do: super(init_arg)

  @doc false
  def init(args) do
    session_id =
      Keyword.get_lazy(args, :session_id, fn ->
        {:ok, session_id} = Zenohex.Session.open()
        session_id
      end)

    key_expr = Keyword.get(args, :key_expr, "key/expr/**")
    querier_opts = Keyword.get(args, :querier_opts, [])

    {:ok, querier_id} = Zenohex.Session.declare_querier(session_id, key_expr, querier_opts)

    {:ok,
     %{
       querier_id: querier_id
     }}
  end

  def handle_call(:id, _from, state) do
    {:reply, state.querier_id, state}
  end

  def handle_call(:stop, _from, state) do
    reply = Zenohex.Querier.undeclare(state.querier_id)
    reason = :normal

    {:stop, reason, reply, state}
  end
end
