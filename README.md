# Zenohex

[![Hex version](https://img.shields.io/hexpm/v/zenohex.svg "Hex version")](https://hex.pm/packages/zenohex)
[![API docs](https://img.shields.io/hexpm/v/zenohex.svg?label=hexdocs "API docs")](https://hexdocs.pm/zenohex/)
[![License](https://img.shields.io/hexpm/l/zenohex.svg)](https://github.com/zenohex/zenohex/blob/main/LICENSE)
[![CI](https://github.com/b5g-ex/zenohex/actions/workflows/ci.yml/badge.svg)](https://github.com/b5g-ex/zenohex/actions/workflows/ci.yml)

Zenohex is the [zenoh](https://zenoh.io/) client library for elixir.

**Currently zenohex uses version 0.10.1-rc of zenoh.  
If you want to communicate with other Zenoh clients or routers, please use the same version.**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `zenohex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:zenohex, "~> 0.2.0-rc.2"}
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

### Low layer Pub/Sub example

```sh
$ iex -S mix
```

```elixir
iex(1)> {:ok, session} = Zenohex.open()
{:ok, #Reference<>}
iex(2)> {:ok, publisher} = Zenohex.Session.declare_publisher(session, "pub/sub")
{:ok, #Reference<>}
iex(3)> {:ok, subscriber} = Zenohex.Session.declare_subscriber(session, "pub/sub")
{:ok, #Reference<>}
iex(4)> Zenohex.Publisher.put(publisher, "Hello Zenoh Dragon")
:ok
iex(5)> Zenohex.Subscriber.recv_timeout(subscriber, 1000)
{:ok, "Hello Zenoh Dragon"}
iex(6)> Zenohex.Subscriber.recv_timeout(subscriber, 1000)
{:error, :timeout}
```

### Practical examples

We implemented practical examples under the [lib/zenohex/examples](https://github.com/b5g-ex/zenohex/tree/v0.2.0-rc.2/lib/zenohex/examples).

Please read the [lib/zenohex/examples/README.md](https://github.com/b5g-ex/zenohex/tree/v0.2.0-rc.2/lib/zenohex/examples/README.md) to use them as your implementation's reference.

## For developer

### How to release

1. Change versions, `mix.exs`, `native/zenohex_nif/Cargo.toml`
2. Run test, this step changes `native/zenohex_nif/Cargo.lock` version
3. Commit them and put the version tag, like v0.2.0-rc.2
4. Puth the tag, like `git push origin v0.2.0-rc.2`. this step triggers the `.github/workflows/nif_precompile.yml`
5. After the artifacts are made, run `mix rustler_precompiled.download Zenohex.Nif --all` to update `checksum-Elixir.Zenohex.Nif.exs` and commit it.
6. Then publish to Hex

(These steps just follows [Recommended flow](https://hexdocs.pm/rustler_precompiled/precompilation_guide.html#recommended-flow).)
