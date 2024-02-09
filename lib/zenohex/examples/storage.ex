defmodule Zenohex.Examples.Storage do
  mix_config = Mix.Project.config()
  version = mix_config[:version]
  base_url = "https://github.com/b5g-ex/zenohex/tree/v#{version}/lib/examples"

  @moduledoc """
  This is the example Storage implementation using Zenohex.

  This Storage is made of `m:Supervisor` and `m:GenServer`.
  If you would like to see the codes, check the followings.

    * Supervisor
      * [lib/zenohex/examples/storage.ex](#{base_url}/storage.ex)
    * GenServer
      * [lib/zenohex/examples/storage/store.ex](#{base_url}/storage/store.ex)
      * [lib/zenohex/examples/storage/subscriber.ex](#{base_url}/storage/subscriber.ex)
      * [lib/zenohex/examples/storage/queryable.ex](#{base_url}/storage/queryable.ex)

  In this example, we made store with `m:Agent`. We think we can use also `:ets`, `:dets` and `:mnesia`.

  ## Getting Started

  ### Start Storage

      iex> alias Zenohex.Examples.Storage
      # if not specify session, key_expr and callback, they are made internally. key_expr is "zenohex/examples/**"
      iex> Storage.start_link()
      # you can also inject your session, key_expr and callback from outside
      iex> Storage.start_link(%{session: your_session, key_expr: "your_key/expression/**"})

  ### Session put/get/delete data with Storage

      iex> alias Zenohex.Examples.Session
      iex> Session.start_link()
      iex> Session.put("zenoh/examples/storage", _value = "put")
      :ok
      iex> Session.get("zenoh/examples/storage", _callback = &IO.inspect/1)
      :ok
      %Zenohex.Sample{
        key_expr: "zenohex/examples/storage",
        value: "put",
        kind: :put,
        reference: #Reference<0.2244884903.1591869505.81651>
      }
      iex> Session.delete("zenoh/examples/storage")
      :ok
      iex> Session.get("zenoh/examples/storage", &IO.inspect/1)
      :ok
  """

  use Supervisor

  alias Zenohex.Examples.Storage

  @doc """
  Start storage.
  """
  def start_link(args \\ %{}) when is_map(args) do
    session = Map.get(args, :session, Zenohex.open!())
    key_expr = Map.get(args, :key_expr, "zenohex/examples/**")
    Supervisor.start_link(__MODULE__, %{session: session, key_expr: key_expr}, name: __MODULE__)
  end

  @doc false
  def init(args) when is_map(args) do
    children = [
      {Storage.Store, %{}},
      {Storage.Subscriber, args},
      {Storage.Queryable, args}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc false
  def child_spec(args), do: super(args)
end
