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

## Subscriber

This Subscriber is made of `Supervisor` and `GenServer`.
If you would like to see the codes, check the followings.

- Supervisor
  - [lib/zenohex/examples/subscriber.ex](/lib/zenohex/examples/subscriber.ex)
- GenServer
  - [lib/zenohex/examples/subscriber/impl.ex](/lib/zenohex/examples/subscriber/impl.ex)

### Start Subscriber

```elixir
iex> alias Zenohex.Examples.Subscriber
# if not specify session, key_expr and callback, they are made internally. key_expr is "zenohex/examples/**",callback is &Logger.debug(inspect(&1))
iex> Subscriber.start_link()
# you can also inject your session, key_expr and callback from outside
iex> Subscriber.start_link(%{session: your_session, key_expr: "your_key/expression/**", callback: &IO.inspect/1})
```

### Subscribed?

```elixir
iex> alias Zenohex.Examples.Publisher
iex> Publisher.start_link()
iex> Publisher.put("subscribed?")
:ok

11:51:53.959 [debug] %Zenohex.Sample{key_expr: "zenohex/examples/pub", value: "subscribed?", kind: :put, reference: #Reference<0.1373489635.746717252.118288>}
```

## PullSubscriber

This PullSubscriber is made of `Supervisor` and `GenServer`.
If you would like to see the codes, check the followings.

- Supervisor
  - [lib/zenohex/examples/pull_subscriber.ex](/lib/zenohex/examples/pull_subscriber.ex)
- GenServer
  - [lib/zenohex/examples/pull_subscriber/impl.ex](/lib/zenohex/examples/pull_subscriber/impl.ex)

### Start PullSubscriber

```elixir
iex> alias Zenohex.Examples.PullSubscriber
# if not specify session, key_expr and callback, they are made internally. key_expr is "zenohex/examples/**",callback is &Logger.debug(inspect(&1))
iex> PullSubscriber.start_link()
# you can also inject your session, key_expr and callback from outside
iex> PullSubscriber.start_link(%{session: your_session, key_expr: "your_key/expression/**", callback: &IO.inspect/1})
```

### Pull data

```elixir
iex> alias Zenohex.Examples.Publisher
iex> Publisher.start_link()
iex> Publisher.put("subscribed?")
:ok
iex> PullSubscriber.pull()
:ok

12:16:47.306 [debug] %Zenohex.Sample{key_expr: "zenohex/examples/pub", value: "subscribed?", kind: :put, reference: #Reference<0.662543409.1019347013.179304>}
```

## Queryable

This Queryable is made of `Supervisor` and `GenServer`.
If you would like to see the codes, check the followings.

- Supervisor
  - [lib/zenohex/examples/queryable.ex](/lib/zenohex/examples/queryable.ex)
- GenServer
  - [lib/zenohex/examples/queryable/impl.ex](/lib/zenohex/examples/queryable/impl.ex)

### Start Queryable

```elixir
iex> alias Zenohex.Examples.Queryable
# if not specify session, key_expr and callback, they are made internally. key_expr is "zenohex/examples/**", callback is &Logger.debug(inspect(&1))
iex> Queryable.start_link()
# you can also inject your session, key_expr and callback from outside
iex> Queryable.start_link(%{session: your_session, key_expr: "your_key/expression/**", callback: &IO.inspect/1})
```

### Queried?

```elixir
iex> alias Zenohex.Examples.Session
iex> Session.start_link()
iex> Session.get("zenohex/examples/get", &IO.inspect/1)
:ok

15:20:17.870 [debug] %Zenohex.Query{key_expr: "zenohex/examples/get", parameters: "", value: :undefined, reference: #Reference<0.3076585362.3463839816.144434>}
```

## Session

This Session is made of `Supervisor` and `GenServer`.
If you would like to see the codes, check the followings.

- Supervisor
  - [lib/zenohex/examples/session.ex](/lib/zenohex/examples/session.ex)
- GenServer
  - [lib/zenohex/examples/session/impl.ex](/lib/zenohex/examples/session/impl.ex)

### Start Session

```elixir
iex> alias Zenohex.Examples.Session
# if not specify session, it is made internally
iex> Session.start_link()
# you can also inject your session and key_expr from outside
iex> Session.start_link(%{session: your_session})
```

### Put data

```elixir
iex> Session.put("zenoh/example/session/put", 42)    # integer
iex> Session.put("zenoh/example/session/put", 42.42) # float
iex> Session.put("zenoh/example/session/put", "42")  # binary
```

### Delete data

```elixir
iex> Session.delete("zenoh/example/session/put")
iex> Session.delete("zenoh/example/session/**")
```

### Get data

```elixir
iex> callback = &IO.inspect/1
iex> Session.get("zenoh/example/session/get", callback)
```

## Storage

This Storage is made of `Supervisor` and `GenServer`.
If you would like to see the codes, check the followings.

- Supervisor
  - [lib/zenohex/examples/storage.ex](/lib/zenohex/examples/storage.ex)
- GenServer
  - [lib/zenohex/examples/storage/store.ex](/lib/zenohex/examples/storage/store.ex)
  - [lib/zenohex/examples/storage/subscriber.ex](/lib/zenohex/examples/storage/subscriber.ex)
  - [lib/zenohex/examples/storage/queryable.ex](/lib/zenohex/examples/storage/queryable.ex)

In this example, we made store with `Agent`. We think we can use also `:ets`, `:dets` and `:mnesia`.

### Start Storage

```elixir
iex> alias Zenohex.Examples.Storage
# if not specify session, key_expr and callback, they are made internally. key_expr is "zenohex/examples/**"
iex> Storage.start_link()
# you can also inject your session, key_expr and callback from outside
iex> Storage.start_link(%{session: your_session, key_expr: "your_key/expression/**"})
```

### Session put/get/delete data with Storage

```elixir
iex> alias Zenohex.Examples.Session
iex> Session.start_link()
iex> Session.put("zenoh/examples/storage", _value = "put")
:ok
iex> Session.get("zenoh/examples/storage", _callback = &IO.inspect/1)
:ok
%Zenohex.Sample{
  key_expr: "zenohex/examples/storage",
  value: "put",
  kind: :put,
  reference: #Reference<0.2244884903.1591869505.81651>
}
iex> Session.delete("zenoh/examples/storage")
:ok
iex> Session.get("zenoh/examples/storage", &IO.inspect/1)
:ok
```
