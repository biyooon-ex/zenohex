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

**Currently, Zenohex uses version 1.5.0 of Zenoh.**

We recommend you use the same version to communicate with other Zenoh clients or routers since version compatibility is somewhat important for Zenoh.
Please also check the description on [Releases](https://github.com/biyooon-ex/zenohex/releases) about the corresponding Zenoh version.

FYI, the development team currently uses the following versions.

- Elixir 1.18.4-otp-27
- Erlang/OTP 27.3.4.2
- Rust 1.85.0

### Installation

`zenohex` is [available in Hex](https://hex.pm/packages/zenohex).

You can install this package into your project by adding `zenohex` to your list of dependencies in `mix.exs`:

```elixir
  defp deps do
    [
      ...
      {:zenohex, "~> 0.5.0"},
      ...
    ]
  end
```

Documentation is also [available in HexDocs](https://hexdocs.pm/zenohex).

Zenohex can be also adapted to your [Nerves](https://nerves-project.org/) application just by adding `zenohex` in `mix.exs`.
Please refer to [pojiro/zenohex_on_nerves](https://github.com/pojiro/zenohex_on_nerves) as the example.

This repository uses [Rustler](https://github.com/rusterlium/rustler) to call Rust (Zenoh) modules from Elixir, and pre-compiled NIF modules are automatically downloaded at `mix compile` time (since v0.1.3).
IOW, if you just want to use this library from your Elixir application, you do not need to prepare a Rust environment.
If you still want to build Rust NIF modules locally, please refer to [this section](#build-nif-module-locally).

### Getting Started

Zenohex has a policy of providing APIs that wrap the basic functionality of Zenoh like other API libraries.

Here is the first step to building an Elixir application and using this feature.

```sh
$ mix deps.get
$ mix compile
$ iex -S mix
```

```elixir
iex()> {:ok, session_id} = Zenohex.Session.open()
{:ok, #Reference<>}
iex()> {:ok, publisher_id} = Zenohex.Session.declare_publisher(session_id, "demo/example/test")
{:ok, #Reference<>}
iex()> {:ok, subscriber_id} = Zenohex.Session.declare_subscriber(session_id, "demo/**")
{:ok, #Reference<>}
iex()> Zenohex.Publisher.put(publisher_id, "Hello Zenoh Dragon")
:ok
iex()> flush()
%Zenohex.Sample{
  attachment: nil,
  congestion_control: :drop,
  encoding: "zenoh/bytes",
  express: false,
  key_expr: "demo/example/test",
  kind: :put,
  payload: "Hello Zenoh Dragon",
  priority: :data,
  timestamp: nil
}
:ok
```

### Practical examples

We implemented practical examples under the [lib/zenohex/examples](https://github.com/b5g-ex/zenohex/tree/main/lib/zenohex/examples).
Since they consist of `GenServer`, we think they are useful as examples of more Elixir-like applications.

## For developers

For most users, this section should be skipped.

### Build NIF module locally

This subsection is for developers who want to build NIF module locally in your Elixir application or try to use this repository itself for the contribution (very welcome!!).

First, please install and configure the Rust environment according to [the instructions on the official site](https://www.rust-lang.org/tools/install).

Then, add the following to your config file (e.g., `config/config.exs`) or make sure it is added.

```elixir
import Config

config :rustler_precompiled, :force_build, zenohex: true
```

When you want to build NIF module locally into your project, install Rustler by adding `rustler` to your list of dependencies in `mix.exs`:

```elixir
  defp deps do
    [
      ...
      {:zenohex, "~> 0.5.0"},
      {:rustler, ">= 0.0.0", optional: true},
      ...
    ]
  end
```

### Versions of dependencies

We think the correspondence between Zenoh (cargo crate) and Rustler is sensitive.
Also, the version number of Rustler is specified in both mix.exs (Elixir hex package) and Cargo.toml (Rust cargo crate).
Therefore, we clearly specify these version numbers with `==` in mix.exs and `=` in Cargo.toml.

### How to release

These steps just follow the [Recommended flow of rustler_precompiled](https://hexdocs.pm/rustler_precompiled/precompilation_guide.html#recommended-flow).

1. Change versions, `mix.exs`, `native/zenohex_nif/Cargo.toml`
2. Run test, this step changes `native/zenohex_nif/Cargo.lock` version
3. Commit them and put the version tag, like v0.2.0
4. Puth the tag, like `git push origin v0.2.0`. This step triggers the `.github/workflows/nif_precompile.yml`
5. After the artifacts are made, run `mix rustler_precompiled.download Zenohex.Nif --all` to update `checksum-Elixir.Zenohex.Nif.exs` and commit it
6. Then publish to Hex

## Resources

- Zenoh meets Elixir in Japan
  - presented in [Zenoh User Meeting 2023](https://www.zettascale.tech/news/zenoh-user-meeting-2023/) at 2023/12/12
  - [SpeakerDeck](https://speakerdeck.com/takasehideki/zenoh-meets-elixir-in-japan)
  - [YouTube archive](https://www.youtube.com/watch?v=4TYn_l6rXIg)
- Zenohex - an eloquent, scalable and fast communication library for Elixir
  - presented in [Code BEAM America 2024](https://codebeamamerica.com/) at 2024/03/07
  - [SpeakerDeck](https://speakerdeck.com/takasehideki/zenohex-an-eloquent-scalable-and-fast-communication-library-for-elixir)
  - [YouTube archive](https://www.youtube.com/watch?v=9DIamjWqass)

## License

The source code of this repository itself is published under [MIT License](https://github.com/b5g-ex/zenohex/blob/main/LICENSE).  
Please note that this repository mainly uses [Zenoh which is licensed under Apache 2.0 and EPL 2.0](https://github.com/eclipse-zenoh/zenoh/blob/main/LICENSE) and [Rustler which is licensed under either of Apache 2.0 or MIT](https://github.com/rusterlium/rustler?tab=readme-ov-file#license).
