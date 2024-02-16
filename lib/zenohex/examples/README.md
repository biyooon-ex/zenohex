# Zenohex.Examples

This README shows how to use following each example implementations.

- [Zenohex.Examples.Publisher](#publisher)
- [Zenohex.Examples.Subscriber](#subscriber)
- [Zenohex.Examples.PullSubscriber](#pullsubscriber)
- [Zenohex.Examples.Queryable](#queryable)
- [Zenohex.Examples.Session](#session)
- [Zenohex.Examples.Storage](#storage)

## Publisher

This Publisher is made of `Supervisor` and `GenServer`.
If you would like to see the codes, check the followings.

- Supervisor
  - [/lib/zenohex/examples/publisher.ex](/lib/zenohex/examples/publisher.ex)
- GenServer
  - [/lib/zenohex/examples/publisher/impl.ex](/lib/zenohex/examples/publisher/impl.ex)

### Start Publisher

```elixir
iex> alias Zenohex.Examples.Publisher
# if not specify session and key_expr, they are made internally. key_expr is "zenohex/examples/pub"
iex> Publisher.start_link()
# you can also inject your session and key_expr from outside
iex> Publisher.start_link(%{session: your_session, key_expr: "your_key/expression"})
```

### Put data

```elixir
iex> Publisher.put(42)    # integer
iex> Publisher.put(42.42) # float
iex> Publisher.put("42")  # binary
```

### Delete data

```elixir
iex> Publisher.delete()
```

see. [#16](https://github.com/b5g-ex/zenohex/issues/16)

### Change Publisher options

```elixir
iex> Publisher.congestion_control(:block)
iex> Publisher.priority(:real_time)
```

see. Supported options, [Zenohex.Publisher.Options](/lib/zenohex/publisher.ex)

### Subscriber

### PullSubscriber

### Queryable

### Session

### Storage
