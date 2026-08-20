/// Default channel capacity, overridable via `ZENOHEX_CHANNEL_CAPACITY`. Bounds
/// two independent things differently, not one:
/// - Zenoh -> native queue: when full, `Fifo` blocks the Zenoh callback thread
///   until this forwarder drains a slot; `Ring` drops the oldest item instead
///   and never blocks it.
/// - native queue -> BEAM mailbox: `send_and_clear` does not wait for the BEAM
///   process to consume its mailbox, so a slow/stuck consumer can still grow
///   that mailbox unbounded regardless of this value.
const DEFAULT_CHANNEL_CAPACITY: usize = 256;

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

impl ChannelKind {
    // WHY: env var switch for now; a Config-level API is a planned follow-up.
    //      Unset falls back to Fifo with the default capacity; a set but
    //      unrecognized/invalid value raises instead of silently falling back.
    pub fn from_env() -> rustler::NifResult<Self> {
        let capacity = channel_capacity_from_env()?;

        match std::env::var("ZENOHEX_CHANNEL_KIND") {
            Err(std::env::VarError::NotPresent) => Ok(ChannelKind::Fifo { capacity }),
            Ok(value) if value.eq_ignore_ascii_case("fifo") => Ok(ChannelKind::Fifo { capacity }),
            Ok(value) if value.eq_ignore_ascii_case("ring") => Ok(ChannelKind::Ring { capacity }),
            Ok(value) => Err(rustler::Error::RaiseTerm(Box::new(
                crate::helper::exception::ArgumentError {
                    message: format!(
                        "invalid ZENOHEX_CHANNEL_KIND {value:?}, expected \"fifo\" or \"ring\""
                    ),
                },
            ))),
            Err(std::env::VarError::NotUnicode(_)) => Err(rustler::Error::RaiseTerm(Box::new(
                crate::helper::exception::ArgumentError {
                    message: "ZENOHEX_CHANNEL_KIND is not valid unicode".to_string(),
                },
            ))),
        }
    }
}

fn channel_capacity_from_env() -> rustler::NifResult<usize> {
    match std::env::var("ZENOHEX_CHANNEL_CAPACITY") {
        Err(std::env::VarError::NotPresent) => Ok(DEFAULT_CHANNEL_CAPACITY),
        Ok(value) => value.parse::<usize>().map_err(|_| {
            rustler::Error::RaiseTerm(Box::new(crate::helper::exception::ArgumentError {
                message: format!(
                    "invalid ZENOHEX_CHANNEL_CAPACITY {value:?}, expected a positive integer"
                ),
            }))
        }),
        Err(std::env::VarError::NotUnicode(_)) => Err(rustler::Error::RaiseTerm(Box::new(
            crate::helper::exception::ArgumentError {
                message: "ZENOHEX_CHANNEL_CAPACITY is not valid unicode".to_string(),
            },
        ))),
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
pub fn spawn_forwarder<T, F>(pid: rustler::LocalPid, handler: ChannelHandler<T>, encode: F) -> rustler::NifResult<()>
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

