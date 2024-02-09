defmodule Zenohex.Examples.Publisher do
  mix_config = Mix.Project.config()
  version = mix_config[:version]
  base_url = "https://github.com/b5g-ex/zenohex/tree/v#{version}/lib/examples"

  @moduledoc """
  This is the example Publisher implementation using Zenohex.

  This Publisher is made of `m:Supervisor` and `m:GenServer`.
  If you would like to see the codes, check the followings.

    * Supervisor
      * [lib/zenohex/examples/publisher.ex](#{base_url}/publisher.ex)
    * GenServer
      * [lib/zenohex/examples/publisher/impl.ex](#{base_url}/publisher/impl.ex)

  ## Getting Started

  ### Start Publisher

      iex> alias Zenohex.Examples.Publisher
      # if not specify session and key_expr, they are made internally. key_expr is "zenohex/examples/pub"
      iex> Publisher.start_link()
      # you can also inject your session and key_expr from outside
      iex> Publisher.start_link(%{session: your_session, key_expr: "your_key/expression"})

  ### Put data

      iex> Publisher.put(42)    # integer
      iex> Publisher.put(42.42) # float
      iex> Publisher.put("42")  # binary

  ### Delete data

      iex> Publisher.delete()

  ### Change Publisher options

      iex> Publisher.congestion_control(:block)
      iex> Publisher.priority(:real_time)

  see. Supported options, `m:Zenohex.Publisher.Options`
  """

  use Supervisor

  alias Zenohex.Examples.Publisher

  @doc """
  Start Publisher.
  """
  def start_link(args \\ %{}) when is_map(args) do
    session = Map.get(args, :session, Zenohex.open!())
    key_expr = Map.get(args, :key_expr, "zenohex/examples/pub")
    Supervisor.start_link(__MODULE__, %{session: session, key_expr: key_expr}, name: __MODULE__)
  end

  @doc "Put data."
  @spec put(integer() | float() | binary()) :: :ok
  defdelegate put(value), to: Publisher.Impl

  @doc "Delete data."
  @spec delete() :: :ok
  defdelegate delete(), to: Publisher.Impl

  @doc "Change congestion control."
  @spec congestion_control(Zenohex.Publisher.Options.congestion_control()) :: :ok
  defdelegate congestion_control(option), to: Publisher.Impl

  @doc "Change priority."
  @spec priority(Zenohex.Publisher.Options.priority()) :: :ok
  defdelegate priority(option), to: Publisher.Impl

  @doc false
  def init(args) when is_map(args) do
    children = [
      {Publisher.Impl, args}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc false
  def child_spec(args), do: super(args)
end
