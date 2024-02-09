defmodule Zenohex.Examples.Queryable do
  mix_config = Mix.Project.config()
  version = mix_config[:version]
  base_url = "https://github.com/b5g-ex/zenohex/tree/v#{version}/lib/examples"

  @moduledoc """
  This is the example Queryable implementation using Zenohex.

  This Queryable is made of `m:Supervisor` and `m:GenServer`.
  If you would like to see the codes, check the followings.

    * Supervisor
      * [lib/zenohex/examples/queryable.ex](#{base_url}/queryable.ex)
    * GenServer
      * [lib/zenohex/examples/queryable/impl.ex](#{base_url}/queryable/impl.ex)

  ## Getting Started

  ### Start Queryable

      iex> alias Zenohex.Examples.Queryable
      # if not specify session, key_expr and callback, they are made internally. key_expr is "zenohex/examples/**", callback is &Logger.debug(inspect(&1))
      iex> Queryable.start_link()
      # you can also inject your session, key_expr and callback from outside
      iex> Queryable.start_link(%{session: your_session, key_expr: "your_key/expression/**", callback: &IO.inspect/1})

  ### Queried?

      iex> alias Zenohex.Examples.Session
      iex> Session.start_link()
      iex> Session.get("zenohex/examples/get", &IO.inspect/1)
      :ok
      
      15:20:17.870 [debug] %Zenohex.Query{key_expr: "zenohex/examples/get", parameters: "", value: :undefined, reference: #Reference<0.3076585362.3463839816.144434>}
  """

  use Supervisor

  require Logger

  alias Zenohex.Examples.Queryable

  @doc """
  Start Queryable.
  """
  def start_link(args \\ %{}) when is_map(args) do
    session = Map.get(args, :session, Zenohex.open!())
    key_expr = Map.get(args, :key_expr, "zenohex/examples/**")
    callback = Map.get(args, :callback, &Logger.debug(inspect(&1)))

    Supervisor.start_link(__MODULE__, %{session: session, key_expr: key_expr, callback: callback},
      name: __MODULE__
    )
  end

  @doc false
  def init(args) when is_map(args) do
    children = [
      {Queryable.Impl, args}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc false
  def child_spec(args), do: super(args)
end
