/// Selects the delivery semantics used between a Zenoh callback and the
/// forwarder thread. `Fifo` (default, matches Zenoh's own default handler)
/// blocks the Zenoh callback thread when full and never drops. `Ring` never
/// blocks it, dropping the oldest item instead. Both produce a `Clone`-able
/// handler, so `.handler().clone()` keeps working the same way regardless of
/// which one is selected via `.with(kind)`.
#[derive(Clone, Copy)]
pub enum ChannelKind {
    Fifo { capacity: usize },
    Ring { capacity: usize },
}

// WHY: `Zenohex.ChannelConfig.get()` resolves `config :zenohex, channel_kind:
//      ..., channel_capacity: ...` on the Elixir side and passes it as a
//      `{:fifo | :ring, pos_integer()}` tuple, so every call site decodes it
//      the same way instead of each NIF re-reading application config itself.
impl<'a> rustler::Decoder<'a> for ChannelKind {
    fn decode(term: rustler::Term<'a>) -> rustler::NifResult<Self> {
        let (kind, capacity): (rustler::Atom, usize) = term.decode()?;
        if kind == crate::atoms::fifo() {
            Ok(ChannelKind::Fifo { capacity })
        } else if kind == crate::atoms::ring() {
            Ok(ChannelKind::Ring { capacity })
        } else {
            Err(rustler::Error::BadArg)
        }
    }
}

pub enum ChannelHandler<T> {
    Fifo(zenoh::handlers::FifoChannelHandler<T>),
    Ring(crate::helper::ring_channel::RingChannelHandler<T>),
}

impl<T: Clone> Clone for ChannelHandler<T> {
    fn clone(&self) -> Self {
        match self {
            ChannelHandler::Fifo(handler) => ChannelHandler::Fifo(handler.clone()),
            ChannelHandler::Ring(handler) => ChannelHandler::Ring(handler.clone()),
        }
    }
}

impl<T> ChannelHandler<T> {
    pub fn iter(&self) -> ChannelIter<'_, T> {
        match self {
            ChannelHandler::Fifo(handler) => ChannelIter::Fifo(handler.iter()),
            ChannelHandler::Ring(handler) => ChannelIter::Ring(handler.iter()),
        }
    }
}

pub enum ChannelIter<'a, T> {
    Fifo(zenoh::handlers::fifo::Iter<'a, T>),
    Ring(crate::helper::ring_channel::RingIter<'a, T>),
}

impl<T> Iterator for ChannelIter<'_, T> {
    type Item = T;

    fn next(&mut self) -> Option<T> {
        match self {
            ChannelIter::Fifo(iter) => iter.next(),
            ChannelIter::Ring(iter) => iter.next(),
        }
    }
}

impl<T: Send + 'static> zenoh::handlers::IntoHandler<T> for ChannelKind {
    type Handler = ChannelHandler<T>;

    fn into_handler(self) -> (zenoh::handlers::Callback<T>, Self::Handler) {
        match self {
            ChannelKind::Fifo { capacity } => {
                let (callback, handler) =
                    zenoh::handlers::FifoChannel::new(capacity).into_handler();
                (callback, ChannelHandler::Fifo(handler))
            }
            ChannelKind::Ring { capacity } => {
                let (callback, handler) =
                    crate::helper::ring_channel::RingChannel::new(capacity).into_handler();
                (callback, ChannelHandler::Ring(handler))
            }
        }
    }
}

// WHY: Zenoh may invoke callbacks from multiple worker threads. Sending directly from
//      each callback thread via a fresh `OwnedEnv` races with other callback threads
//      targeting the same pid and can reorder deliveries. Draining `handler` from a
//      single dedicated thread and reusing one `OwnedEnv` preserves delivery order and
//      keeps `send_and_clear` allocations low.
pub fn spawn_forwarder<T, F>(
    pid: rustler::LocalPid,
    handler: ChannelHandler<T>,
    encode: F,
) -> rustler::NifResult<()>
where
    T: Send + 'static,
    F: for<'a> Fn(rustler::Env<'a>, T) -> rustler::Term<'a> + Send + 'static,
{
    std::thread::spawn(move || {
        let mut owned_env = rustler::OwnedEnv::new();
        let mut iter = handler.iter();
        let mut was_full = false;

        loop {
            // WHY: surfaces backpressure to the user instead of failing silently.
            //      A full Fifo means Zenoh's callback thread is blocked on this
            //      entity right now; only logging on the not-full -> full
            //      transition avoids spamming the log once per message during
            //      sustained overload.
            if let ChannelHandler::Fifo(fifo) = &handler {
                let is_full = fifo.is_full();
                if is_full && !was_full {
                    log::warn!(
                        "zenohex_nif: fifo channel is full, Zenoh's callback thread is blocked until it drains"
                    );
                }
                was_full = is_full;
            }

            let Some(item) = iter.next() else { break };

            let outcome = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
                owned_env.send_and_clear(&pid, |env| encode(env, item))
            }));

            // WHY: a single thread now forwards every message for this entity's whole
            //      lifetime, so a panic in `encode` must not kill it silently. Log and
            //      replace `owned_env` (its state after an unwind is not guaranteed)
            //      instead of letting the thread die and delivery stop forever.
            if outcome.is_err() {
                log::error!("zenohex_nif: encode panicked while forwarding, message dropped");
                owned_env = rustler::OwnedEnv::new();
            }
        }
    });
    Ok(())
}
