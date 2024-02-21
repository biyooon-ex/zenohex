# Zenohex

[![Hex version](https://img.shields.io/hexpm/v/zenohex.svg "Hex version")](https://hex.pm/packages/zenohex)
[![API docs](https://img.shields.io/hexpm/v/zenohex.svg?label=hexdocs "API docs")](https://hexdocs.pm/zenohex/)
[![License](https://img.shields.io/hexpm/l/zenohex.svg)](https://github.com/zenohex/zenohex/blob/main/LICENSE)
[![CI](https://github.com/b5g-ex/zenohex/actions/workflows/ci.yml/badge.svg)](https://github.com/b5g-ex/zenohex/actions/workflows/ci.yml)

Zenohex is Elixir API for [Zenoh](https://zenoh.io/).

Zenoh is a new protocol for Zero Overhead Pub/Sub, Store/Query and Compute.
The most obvious explanation is that Zenoh offers publication subscription-based communication capabilities.
Within the same network, Zenoh can autonomously search for communication partner nodes like DDS.
Between different networks, Zenoh can search for nodes through a broker (called a router in Zenoh) like MQTT.
Also, Zenoh provides functions for database operations and computational processing based on the Key-Value Store.
Moreover, it has plugins/bridges for interoperability with MQTT, DDS, REST, etc. as communication middleware, and influxdb, RocksDB, etc. as database stacks.

For more details about Zenoh, please refer to the official resources.
- [Official Page](https://zenoh.io/)
- [GitHub](https://github.com/eclipse-zenoh/zenoh)
- [Discord](https://discord.gg/vSDSpqnbkm)

Zenoh's core modules are implemented in Rust, but API libraries in various programming languages such as Python ([zenoh-python](https://github.com/eclipse-zenoh/zenoh-python)), C ([zenoh-c](https://github.com/eclipse-zenoh/zenoh-c)), C++ ([zenoh-cpp](https://github.com/eclipse-zenoh/zenoh-cpp)) are officially provided.

So what we need is [Elixir](https://elixir-lang.org/)!
With this library, you can call Zenoh from your Elixir application to perform its basic processing.
This allows the creation and communication of a large number of fault-tolerant nodes with little memory load (we hope :D

## Usage

**Currently, Zenohex uses version 0.10.1-rc of Zenoh.  
We recommend you use the same version to communicate with other Zenoh clients or routers.

### Installation

`zenohex` is [available in Hex](https://hex.pm/packages/zenohex).

You can install this package into your project by adding `zenohex` to your list of dependencies in `mix.exs`:

```elixir
  defp deps do
    [
      ...
      {:zenohex, "~> 0.2.0-rc.2"},
      ...
    ]
  end
```

Documentation is also [available in HexDocs](https://hexdocs.pm/zenohex).

Zenohex can be also adapted to your [Nerves](https://nerves-project.org/) application just by adding `zenohex` in `mix.exs`.
Please refer to [pojiro/nerves_zenohex](https://github.com/pojiro/nerves_zenohex) as the example.

### [optional] Build NIF module locally

For most users, this section should be skipped.

This repository uses [Rustler](https://github.com/rusterlium/rustler) to call Rust (Zenoh) modules from Elixir, and pre-compiled NIF modules are automatically downloaded at `mix compile` time (since v0.1.3). 
IOW, if you just want to use this library from your Elixir application, you do not need to prepare a Rust environment.

If you still want to build Rust NIF modules locally, first install and configure the Rust environment according to [the instructions on the official site](https://www.rust-lang.org/tools/install).

Then, add the following to your config file (e.g., `config/config.exs`).

```elixir
import Config

config :rustler_precompiled, :force_build, zenohex: true
```

Finally, install Rustler into your project by adding `rustler` to your list of dependencies in `mix.exs`:

```elixir
  defp deps do
    [
      ...
      {:zenohex, "~> 0.2.0-rc.2"},
      {:rustler, ">= 0.0.0", optional: true},
      ...
    ]
  end
```

### Getting Started

Zenohex has a policy of providing APIs that wrap the basic functionality of Zenoh like other API libraries.

Here is the first step to building an Elixir application and using this feature.

```sh
$ mix deps.get
$ mix compile
$ iex -S mix
```

```elixir
iex()> {:ok, session} = Zenohex.open()
{:ok, #Reference<>}
iex()> {:ok, publisher} = Zenohex.Session.declare_publisher(session, "demo/example/test")
{:ok, #Reference<>}
iex()> {:ok, subscriber} = Zenohex.Session.declare_subscriber(session, "demo/**")
{:ok, #Reference<>}
iex()> Zenohex.Publisher.put(publisher, "Hello Zenoh Dragon")
:ok
iex()> Zenohex.Subscriber.recv_timeout(subscriber, 1000)
{:ok,
 %Zenohex.Sample{
   key_expr: "demo/example/test",
   value: "Hello Zenoh Dragon",
   kind: :put,
   reference: #Reference<>
 }}
iex()> Zenohex.Subscriber.recv_timeout(subscriber, 1000)
{:error, :timeout}
```

### Practical examples

We implemented practical examples under the [lib/zenohex/examples](https://github.com/b5g-ex/zenohex/tree/v0.2.0-rc.2/lib/zenohex/examples).
Since they consist of `Supervisor` and `GenServer`, we think they are useful as examples of more Elixir-like applications.

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
