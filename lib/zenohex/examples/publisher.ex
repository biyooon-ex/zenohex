defmodule Zenohex.Examples.Publisher do
  @moduledoc """
  Example `GenServer` implementation of `Publisher`
  using `Zenohex.Session.declare_publisher/3`.

  This example demonstrates how to publish.

  For the actual implementation, please refer to the following,

  - #{Zenohex.MixProject.project()[:source_url]}/tree/main/#{Path.relative_to_cwd(__ENV__.file)}

  ## Examples

      iex> Zenohex.Examples.Publisher.start_link([])
  """

  use GenServer

  @doc """
  Sends a `Zenohex.Sample` with `kind: :put` and the given payload.
  """
  @spec put(module(), binary()) :: :ok | {:error, reason :: term()}
  def put(name \\ __MODULE__, payload) do
    GenServer.call(name, {:put, payload})
  end

  @doc """
  Sends a `Zenohex.Sample` with `kind: :delete`.
  """
  @spec delete(module()) :: :ok | {:error, reason :: term()}
  def delete(name \\ __MODULE__) do
    GenServer.call(name, :delete)
  end

  @doc """
  Starts #{__MODULE__}.

  ## Parameters

    - `args` – a keyword list that can include the following keys:
      - `:session_id` – the ID of the session
      - `:key_expr` – the key expression to subscribe to
  """
  @spec start_link([
          {:session_id, Zenohex.Session.id()}
          | {:key_expr, String.t()}
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

    {:ok, publisher_id} = Zenohex.Session.declare_publisher(session_id, key_expr)

    {:ok,
     %{
       publisher_id: publisher_id
     }}
  end

  def handle_call({:put, payload}, _from, state) do
    reply = Zenohex.Publisher.put(state.publisher_id, payload)

    {:reply, reply, state}
  end

  def handle_call(:delete, _from, state) do
    reply = Zenohex.Publisher.delete(state.publisher_id)

    {:reply, reply, state}
  end

  def handle_call(:stop, _from, state) do
    reply = Zenohex.Publisher.undeclare(state.publisher_id)
    reason = :normal

    {:stop, reason, reply, state}
  end
end
