defmodule Zenohex.Examples.PullSubscriber do
  mix_config = Mix.Project.config()
  version = mix_config[:version]
  base_url = "https://github.com/b5g-ex/zenohex/tree/v#{version}/lib/examples"

  @moduledoc """
  This is the example PullSubscriber implementation using Zenohex.

  This PullSubscriber is made of `m:Supervisor` and `m:GenServer`.
  If you would like to see the codes, check the followings.

    * Supervisor
      * [lib/zenohex/examples/pull_subscriber.ex](#{base_url}/pull_subscriber.ex)
    * GenServer
      * [lib/zenohex/examples/pull_subscriber/impl.ex](#{base_url}/pull_subscriber/impl.ex)

  ## Getting Started

  ### Start PullSubscriber

      iex> alias Zenohex.Examples.PullSubscriber
      # if not specify session, key_expr and callback, they are made internally. key_expr is "zenohex/examples/**",callback is &Logger.debug(inspect(&1))
      iex> PullSubscriber.start_link()
      # you can also inject your session, key_expr and callback from outside
      iex> PullSubscriber.start_link(%{session: your_session, key_expr: "your_key/expression/**", callback: &IO.inspect/1})

  ### Pull data

      iex> alias Zenohex.Examples.Publisher
      iex> Publisher.start_link()
      iex> Publisher.put("subscribed?")
      :ok
      iex> PullSubscriber.pull()
      :ok
      
      12:16:47.306 [debug] %Zenohex.Sample{key_expr: "zenohex/examples/pub", value: "subscribed?", kind: :put, reference: #Reference<0.662543409.1019347013.179304>}
  """

  use Supervisor

  require Logger

  alias Zenohex.Examples.PullSubscriber

  @doc """
  Start PullSubscriber.
  """
  def start_link(args \\ %{}) when is_map(args) do
    session = Map.get(args, :session) || Zenohex.open!()
    key_expr = Map.get(args, :key_expr, "zenohex/examples/**")
    callback = Map.get(args, :callback, &Logger.debug(inspect(&1)))

    Supervisor.start_link(__MODULE__, %{session: session, key_expr: key_expr, callback: callback},
      name: __MODULE__
    )
  end

  @doc "Pull data."
  @spec pull() :: :ok
  defdelegate pull(), to: PullSubscriber.Impl

  @doc false
  def init(args) when is_map(args) do
    children = [
      {PullSubscriber.Impl, args}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc false
  def child_spec(args), do: super(args)
end
