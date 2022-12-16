# Zenohex

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `zenohex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:zenohex, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/zenohex>.

### install rust.

## Getting Started

### terminal 1
```
iex -S mix
iex> NifZenoh.call_sub_zenoh
```

### terminal 2
```
iex -S mix
iex> session = NifZenoh.open
iex> publisher = NifZenoh.nif_declare_publisher(session, "demo/example/zenoh-rs-pub")
iex> NifZenoh.nif_put(publisher, "Hello zenoh?")
```