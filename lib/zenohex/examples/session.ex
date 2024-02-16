defmodule Zenohex.Examples.Session do
  mix_config = Mix.Project.config()
  version = mix_config[:version]
  base_url = "https://github.com/b5g-ex/zenohex/tree/v#{version}/lib/examples"

  @moduledoc """
  This is the example Session implementation using Zenohex.

  This Session is made of `m:Supervisor` and `m:GenServer`.
  If you would like to see the codes, check the followings.

    * Supervisor
      * [lib/zenohex/examples/session.ex](#{base_url}/session.ex)
    * GenServer
      * [lib/zenohex/examples/session/impl.ex](#{base_url}/session/impl.ex)

  ## Getting Started

  ### Start Session

      iex> alias Zenohex.Examples.Session
      # if not specify session, it is made internally
      iex> Session.start_link()
      # you can also inject your session and key_expr from outside
      iex> Session.start_link(%{session: your_session})

  ### Put data

      iex> Session.put("zenoh/example/session/put", 42)    # integer
      iex> Session.put("zenoh/example/session/put", 42.42) # float
      iex> Session.put("zenoh/example/session/put", "42")  # binary

  ### Delete data

      iex> Session.delete("zenoh/example/session/put")
      iex> Session.delete("zenoh/example/session/**")

  ### Get data

      iex> callback = &IO.inspect/1
      iex> Session.get("zenoh/example/session/get", callback)

  """

  use Supervisor

  alias Zenohex.Examples.Session

  @doc """
  Start Session.
  """
  def start_link(args \\ %{}) when is_map(args) do
    session = Map.get(args, :session) || Zenohex.open!()
    Supervisor.start_link(__MODULE__, %{session: session}, name: __MODULE__)
  end

  @doc "Put data."
  @spec put(String.t(), integer() | float() | binary()) :: :ok
  defdelegate put(key_expr, value), to: Session.Impl

  @doc "Delete data."
  @spec delete(String.t()) :: :ok
  defdelegate delete(key_expr), to: Session.Impl

  @doc "Set disconnected callback."
  @spec set_disconnected_cb(function) :: :ok
  defdelegate set_disconnected_cb(callback), to: Session.Impl

  @doc "Get data."
  @spec get(String.t(), function()) :: :ok
  defdelegate get(selector, callback), to: Session.Impl

  @doc false
  def init(args) when is_map(args) do
    children = [
      {Session.Impl, args}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc false
  def child_spec(args), do: super(args)
end
