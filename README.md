# Zenohex

[![Hex version](https://img.shields.io/hexpm/v/zenohex.svg "Hex version")](https://hex.pm/packages/zenohex)
[![API docs](https://img.shields.io/hexpm/v/rclex.svg?label=hexdocs "API docs")](https://hexdocs.pm/zenohex/)
[![License](https://img.shields.io/hexpm/l/zenohex.svg)](https://github.com/zenohex/zenohex/blob/main/LICENSE)

Zenohex is the [zenoh](https://zenoh.io/) client library for elixir.

**Currently zenohex uses version 0.10.1-rc of zenoh.  
If you want to communicate with other Zenoh clients or routers, please use the same version.**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `zenohex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:zenohex, "~> 0.1.5"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/zenohex>.

### Install rust (Optional)

Since version 0.1.3, Zenohex uses rustler precompiled and does not require Rust to be installed.

If you want to build rust NIFs code, please add following to your config file.

```elixir
config :rustler_precompiled, :force_build, zenohex: true
```

https://www.rust-lang.org/tools/install

## Getting Started

### Pub/Sub example

```sh
$ iex -S mix
```

```elixir
iex(1)> session = Zenohex.open!()
#Reference<>
iex(2)> publisher = Zenohex.Session.declare_publisher!(session, "pub/sub")
#Reference<>
iex(3)> subscriber = Zenohex.Session.declare_subscriber!(session, "pub/sub")
#Reference<>
iex(4)> Zenohex.Publisher.put!(publisher, "Hello Zenoh Dragon")
:ok
iex(5)> Zenohex.Subscriber.recv_timeout!(subscriber, 1000)
"Hello Zenoh Dragon"
iex(6)> Zenohex.Subscriber.recv_timeout!(subscriber, 1000)
:timeout
```

## For developer

### How to release

Follow [Recommended flow](https://hexdocs.pm/rustler_precompiled/precompilation_guide.html#recommended-flow).
