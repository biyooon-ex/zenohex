# Zenohex

[![Hex version](https://img.shields.io/hexpm/v/zenohex.svg "Hex version")](https://hex.pm/packages/zenohex)
[![API docs](https://img.shields.io/hexpm/v/rclex.svg?label=hexdocs "API docs")](https://hexdocs.pm/zenohex/)
[![License](https://img.shields.io/hexpm/l/zenohex.svg)](https://github.com/zenohex/zenohex/blob/main/LICENSE)

Zenohex is the [zenoh](https://zenoh.io/) client library for elixir.

Currently zenohex uses version 0.7.0-rc of zenoh.
If you want to communicate with Rust version of Zenoh, please use the same version. 

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `zenohex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:zenohex, "~> 0.1.4"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/zenohex>.

### Install rust (Optional)
Since version 0.1.3, Zenohex uses rustler precompiled and does not require Rust to be installed.

If you need to build rust NIFs code, please set the environment variable and install rust.
```
export RUSTLER_PRECOMPILATION_EXAMPLE_BUILD=1
```
https://www.rust-lang.org/tools/install

## Getting Started

### Publisher example
#### terminal 1 (Subscriber)
```
iex -S mix
iex> NifZenoh.tester_sub "demo/example/zenoh-rs-pub"
```

#### terminal 2 (Publisher)
```
iex -S mix
iex> session = Zenohex.open
iex> {:ok, publisher} = Session.declare_publisher(session, "demo/example/zenoh-rs-pub")
iex> Publisher.put(publisher, "Hello zenoh?")
```

### Subscriber example
```
(Subscriber)
iex -S mix
iex> session = Zenohex.open
iex> Session.declare_subscriber(session, "demo/example/zenoh-rs-pub", fn m -> IO.inspect(m) end)
(third argument is callback function)

(Publisher)
iex> {:ok, publisher} = Session.declare_publisher(session, "demo/example/zenoh-rs-pub")
iex> Publisher.put(publisher, "Hello zenoh?")
```
