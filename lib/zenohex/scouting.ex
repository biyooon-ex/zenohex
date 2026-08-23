defmodule Zenohex.Scouting do
  @moduledoc """
  Provides functions for Zenoh scouting, which allows discovery of peers, routers, and clients.

  This module wraps Zenoh's scouting functionality, enabling Elixir programs to send scout messages,
  receive `Hello` replies, and manage periodic scouting processes.

  See the `Zenohex.Scouting.Hello` module for details on the reply format.
  """

  @type what :: :peer | :router | :client
  @type what_matcher :: nonempty_list(what())
  @type what_or_matcher :: what() | what_matcher()
  @type scout :: reference()

  defmodule Hello do
    @moduledoc """
    A struct that corresponds one-to-one to `zenoh::scouting::Hello`.

    see. https://docs.rs/zenoh/latest/zenoh/scouting/struct.Hello.html

    ## Examples

        iex> Zenohex.scout(:peer, Zenohex.Config.default(), 100)
        {:ok,
         [
           %Zenohex.Scouting.Hello{
             locators: ["tcp/[fe80::dead:beaf:cafe:1234]:36319",
              "tcp/10.0.123.45:36319"],
             whatami: :peer,
             zid: "de7815fc98e0bdbb69e84ff9653ee26"
           }
         ]}
    """

    @type t :: %__MODULE__{
            locators: [String.t()],
            whatami: :peer | :router | :client,
            zid: Zenohex.Session.zid()
          }

    defstruct [
      :locators,
      :whatami,
      :zid
    ]
  end

  @doc """
  Sends scout messages and waits for Hello replies.

  A single node type or a non-empty list of node types can be specified.
  An empty list is rejected.

  ## Parameters

    - `what`: `:peer`, `:router`, `:client`, or a non-empty list of these atoms.
    - `config`: The configuration to use for scouting
    - `timeout`: Timeout in milliseconds to wait for Hello replies.
  """
  @spec scout(what_or_matcher(), Zenohex.Config.t(), non_neg_integer()) ::
          {:ok, [Hello.t()]} | {:error, :timeout} | {:error, reason :: term()}
  def scout(what_or_matcher, config, timeout) do
    with {:ok, what_matcher} <- normalize_what(what_or_matcher) do
      Zenohex.Nif.scouting_scout(what_matcher, config, timeout)
    end
  end

  @doc """
  Declares a scout that periodically sends scout messages and waits for Hello replies.

  ## Parameters

    - `what`: `:peer`, `:router`, `:client`, or a non-empty list of these atoms.
    - `config`: The configuration to use for scouting
    - `pid`: Process to receive Hello messages. Defaults to the calling process.
      - Messages are delivered as `Zenohex.Scouting.Hello`.
  """
  @spec declare_scout(what_or_matcher(), Zenohex.Config.t(), pid()) ::
          {:ok, scout()} | {:error, reason :: term()}
  def declare_scout(what_or_matcher, config, pid \\ self()) do
    with {:ok, what_matcher} <- normalize_what(what_or_matcher) do
      Zenohex.Nif.scouting_declare_scout(what_matcher, config, pid)
    end
  end

  @doc """
  Stop scouting.
  """
  @spec stop_scout(scout()) :: :ok | {:error, reason :: term()}
  defdelegate stop_scout(scout),
    to: Zenohex.Nif,
    as: :scouting_stop_scout

  defp normalize_what(what_or_matcher) when is_atom(what_or_matcher) do
    normalize_what([what_or_matcher])
  end

  defp normalize_what(what_matcher) when is_list(what_matcher) do
    if what_matcher != [] and Enum.all?(what_matcher, &(&1 in [:peer, :router, :client])) do
      {:ok, what_matcher}
    else
      {:error, :invalid_what_matcher}
    end
  end

  defp normalize_what(_what), do: {:error, :invalid_what_matcher}
end
