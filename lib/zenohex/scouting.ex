defmodule Zenohex.Scouting do
  @moduledoc """
  Provides functions for Zenoh scouting, which allows discovery of peers and routers.

  This module wraps Zenoh's scouting functionality, enabling Elixir programs to send scout messages,
  receive `Hello` replies, and manage periodic scouting processes.

  See the `Zenohex.Scouting.Hello` module for details on the reply format.
  """

  @type what :: :peer | :router
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
            whatami: :peer | :router,
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

  ## Parameters

    - `what`: `:peer` or `:router`.
    - `config`: The configuration to use for scouting
    - `timeout`: Timeout in milliseconds to wait for Hello replies.
  """
  @spec scout(what(), Zenohex.Config.t(), non_neg_integer()) ::
          {:ok, [Hello.t()]} | {:error, :timeout} | {:error, reason :: term()}
  defdelegate scout(what, config, timeout),
    to: Zenohex.Nif,
    as: :scouting_scout

  @doc """
  Declares a scout that periodically sends scout messages and waits for Hello replies.

  ## Parameters

    - `what`: `:peer` or `:router`.
    - `config`: The configuration to use for scouting
    - `pid`: Process to receive Hello messages. Defaults to the calling process.
      - Messages are delivered as `Zenohex.Scouting.Hello`.
  """
  @spec declare_scout(what(), Zenohex.Config.t(), pid()) ::
          {:ok, scout()} | {:error, reason :: term()}
  defdelegate declare_scout(what, config, pid \\ self()),
    to: Zenohex.Nif,
    as: :scouting_declare_scout

  @doc """
  Stop scouting.
  """
  @spec stop_scout(scout()) :: :ok | {:error, reason :: term()}
  defdelegate stop_scout(scout),
    to: Zenohex.Nif,
    as: :scouting_stop_scout
end
