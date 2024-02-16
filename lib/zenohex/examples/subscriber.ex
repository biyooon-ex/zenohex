defmodule Zenohex.Examples.Subscriber do
  mix_config = Mix.Project.config()
  version = mix_config[:version]
  base_url = "https://github.com/b5g-ex/zenohex/tree/v#{version}/lib/examples"

  @moduledoc """
  This is the example Subscriber implementation using Zenohex.

  This Subscriber is made of `m:Supervisor` and `m:GenServer`.
  If you would like to see the codes, check the followings.

    * Supervisor
      * [lib/zenohex/examples/subscriber.ex](#{base_url}/subscriber.ex)
    * GenServer
      * [lib/zenohex/examples/subscriber/impl.ex](#{base_url}/subscriber/impl.ex)

  ## Getting Started

  ### Start Subscriber

      iex> alias Zenohex.Examples.Subscriber
      # if not specify session, key_expr and callback, they are made internally. key_expr is "zenohex/examples/**",callback is &Logger.debug(inspect(&1))
      iex> Subscriber.start_link()
      # you can also inject your session, key_expr and callback from outside
      iex> Subscriber.start_link(%{session: your_session, key_expr: "your_key/expression/**", callback: &IO.inspect/1})

  ### Subscribed?

      iex> alias Zenohex.Examples.Publisher
      iex> Publisher.start_link()
      iex> Publisher.put("subscribed?")
      :ok
      
      11:51:53.959 [debug] %Zenohex.Sample{key_expr: "zenohex/examples/pub", value: "subscribed?", kind: :put, reference: #Reference<0.1373489635.746717252.118288>}
  """

  use Supervisor

  require Logger

  alias Zenohex.Examples.Subscriber

  @doc """
  Start Subscriber.
  """
  def start_link(args \\ %{}) when is_map(args) do
    session = Map.get(args, :session) || Zenohex.open!()
    key_expr = Map.get(args, :key_expr, "zenohex/examples/**")
    callback = Map.get(args, :callback, &Logger.debug(inspect(&1)))

    Supervisor.start_link(__MODULE__, %{session: session, key_expr: key_expr, callback: callback},
      name: __MODULE__
    )
  end

  @doc false
  def init(args) when is_map(args) do
    children = [
      {Subscriber.Impl, args}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc false
  def child_spec(args), do: super(args)
end
