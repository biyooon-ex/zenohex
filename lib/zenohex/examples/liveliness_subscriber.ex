defmodule Zenohex.Examples.LivelinessSubscriber do
  @moduledoc """
  Example `GenServer` implementation of `LivelinessSubscriber`
  using `Zenohex.Liveliness.declare_subscriber/3`.

  This example demonstrates how to subscribe to and react to liveliness updates.

  For the actual implementation, please refer to the following,

  - #{Zenohex.MixProject.project()[:source_url]}/tree/main/#{Path.relative_to_cwd(__ENV__.file)}

  ## Examples

      iex> Zenohex.Examples.LivelinessSubscriber.start_link([])
  """

  use GenServer

  require Logger

  @doc """
  Starts #{__MODULE__}.

  ## Parameters

    - `args` – a keyword list that can include the following keys:
      - `:session_id` – the ID of the session
      - `:key_expr` – the key expression to subscribe to
      - `:callback` – the function to call when a liveliness update occurs
  """
  @spec start_link([
          {:session_id, Zenohex.Session.id()}
          | {:key_expr, String.t()}
          | {:callback, (Zenohex.Sample.t() -> term())}
        ]) :: GenServer.on_start()
  def start_link(args) do
    name = Keyword.get(args, :name, __MODULE__)
    GenServer.start_link(__MODULE__, args, name: name)
  end

  @doc """
  Stops #{__MODULE__}
  """
  @spec stop(module()) :: :ok
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

    key_expr = Keyword.get(args, :key_expr, "key/expr")
    callback = Keyword.get(args, :callback, &Logger.debug("#{inspect(&1)}"))

    {:ok, subscriber_id} =
      Zenohex.Liveliness.declare_subscriber(session_id, key_expr, self())

    {:ok,
     %{
       subscriber_id: subscriber_id,
       key_expr: key_expr,
       callback: callback
     }}
  end

  # NOTE: To handle `kind: :put` and `kind: :delete` differently,
  #       just split `handle_info/2` into multiple clauses with pattern matching.
  def handle_info(%Zenohex.Sample{} = sample, state) do
    state.callback.(sample)

    {:noreply, state}
  end

  def handle_call(:stop, _from, state) do
    reply = Zenohex.Liveliness.undeclare_subscriber(state.subscriber_id)
    reason = :normal

    {:stop, reason, reply, state}
  end
end
