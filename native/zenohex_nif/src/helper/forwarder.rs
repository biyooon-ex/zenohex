/// Channel capacity for `fifo_channel()`. This bounds two independent things
/// differently, not one:
/// - Zenoh -> native queue: when full, `FifoChannel` blocks the Zenoh callback
///   thread trying to push into it until this forwarder drains a slot, which can
///   stall other Zenoh work sharing that thread pool.
/// - native queue -> BEAM mailbox: `send_and_clear` does not wait for the BEAM
///   process to consume its mailbox, so a slow/stuck consumer can still grow
///   that mailbox unbounded regardless of this value; raising the capacity does
///   not protect against this side.
const CHANNEL_CAPACITY: usize = 256;

/// Selects the delivery semantics used between a Zenoh callback and the
/// forwarder thread. `Fifo` blocks the Zenoh callback thread when full and
/// never drops; `Ring` never blocks it and drops the oldest item instead.
/// Both produce a `Clone`-able handler, so `.handler().clone()` keeps working
/// the same way regardless of which one is selected via `.with(kind)`.
#[derive(Clone, Copy)]
pub enum ChannelKind {
    Fifo,
    Ring,
}

impl ChannelKind {
    // WHY: env var switch for now, until a public Elixir API is decided;
    //      set ZENOHEX_CHANNEL_KIND=ring to select Ring for every entity.
    //      An unset var falls back to Fifo, but a set-and-unrecognized value
    //      raises instead of silently falling back, to catch typos.
    pub fn from_env() -> rustler::NifResult<Self> {
        match std::env::var("ZENOHEX_CHANNEL_KIND") {
            Err(std::env::VarError::NotPresent) => Ok(ChannelKind::Fifo),
            Ok(value) if value.eq_ignore_ascii_case("fifo") => Ok(ChannelKind::Fifo),
            Ok(value) if value.eq_ignore_ascii_case("ring") => Ok(ChannelKind::Ring),
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

    // WHY: diagnostic-only (see spawn_forwarder), for observing native queue
    //      fullness directly instead of inferring it from end-to-end message loss.
    fn len(&self) -> usize {
        match self {
            ChannelHandler::Fifo(handler) => handler.len(),
            ChannelHandler::Ring(handler) => handler.len(),
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
            ChannelKind::Fifo => {
                let (callback, handler) =
                    zenoh::handlers::FifoChannel::new(CHANNEL_CAPACITY).into_handler();
                (callback, ChannelHandler::Fifo(handler))
            }
            ChannelKind::Ring => {
                let (callback, handler) =
                    crate::helper::ring_channel::RingChannel::new(CHANNEL_CAPACITY).into_handler();
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
    match (ForwarderExecutor::from_env()?, handler) {
        (ForwarderExecutor::Tokio, ChannelHandler::Fifo(fifo)) => {
            tokio_runtime().spawn(async move {
                let mut owned_env = rustler::OwnedEnv::new();
                let mut max_len = 0usize;
                while let Ok(item) = fifo.recv_async().await {
                    max_len = max_len.max(fifo.len());
                    let outcome = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
                        owned_env.send_and_clear(&pid, |env| encode(env, item))
                    }));
                    if outcome.is_err() {
                        log::error!("zenohex_nif: encode panicked while forwarding, message dropped");
                        owned_env = rustler::OwnedEnv::new();
                    }
                }
                eprintln!(
                    "[zenohex_nif debug] fifo+tokio forwarder done: max_queue_len={max_len} capacity={CHANNEL_CAPACITY}"
                );
            });
        }
        (ForwarderExecutor::Tokio, ChannelHandler::Ring(ring)) => {
            tokio_runtime().spawn(async move {
                let mut owned_env = rustler::OwnedEnv::new();
                let mut max_len = 0usize;
                while let Some(item) = ring.recv_async().await {
                    max_len = max_len.max(ring.len());
                    let outcome = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
                        owned_env.send_and_clear(&pid, |env| encode(env, item))
                    }));
                    if outcome.is_err() {
                        log::error!("zenohex_nif: encode panicked while forwarding, message dropped");
                        owned_env = rustler::OwnedEnv::new();
                    }
                }
                eprintln!(
                    "[zenohex_nif debug] ring+tokio forwarder done: max_queue_len={max_len} capacity={CHANNEL_CAPACITY} dropped={}",
                    ring.dropped_count()
                );
            });
        }
        (_, handler) => {
            std::thread::spawn(move || {
                let mut owned_env = rustler::OwnedEnv::new();
                let mut max_len = 0usize;
                for item in handler.iter() {
                    max_len = max_len.max(handler.len());
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
                let dropped = match &handler {
                    ChannelHandler::Ring(ring) => Some(ring.dropped_count()),
                    ChannelHandler::Fifo(_) => None,
                };
                eprintln!(
                    "[zenohex_nif debug] {}+thread forwarder done: max_queue_len={max_len} capacity={CHANNEL_CAPACITY} dropped={dropped:?}",
                    match &handler {
                        ChannelHandler::Fifo(_) => "fifo",
                        ChannelHandler::Ring(_) => "ring",
                    }
                );
            });
        }
    }
    Ok(())
}

// WHY: prototype/benchmark only (see Cargo.toml), scoped to this file.
#[derive(Clone, Copy)]
enum ForwarderExecutor {
    Thread,
    Tokio,
}

impl ForwarderExecutor {
    fn from_env() -> rustler::NifResult<Self> {
        match std::env::var("ZENOHEX_FORWARDER_EXECUTOR") {
            Err(std::env::VarError::NotPresent) => Ok(ForwarderExecutor::Thread),
            Ok(value) if value.eq_ignore_ascii_case("thread") => Ok(ForwarderExecutor::Thread),
            Ok(value) if value.eq_ignore_ascii_case("tokio") => Ok(ForwarderExecutor::Tokio),
            Ok(value) => Err(rustler::Error::RaiseTerm(Box::new(
                crate::helper::exception::ArgumentError {
                    message: format!(
                        "invalid ZENOHEX_FORWARDER_EXECUTOR {value:?}, expected \"thread\" or \"tokio\""
                    ),
                },
            ))),
            Err(std::env::VarError::NotUnicode(_)) => Err(rustler::Error::RaiseTerm(Box::new(
                crate::helper::exception::ArgumentError {
                    message: "ZENOHEX_FORWARDER_EXECUTOR is not valid unicode".to_string(),
                },
            ))),
        }
    }
}

// WHY: not calling `.worker_threads()` leaves tokio reading `TOKIO_WORKER_THREADS`
//      (falling back to the number of cores), so operators retain the same tuning
//      knob pojiro flagged as a benefit of this approach in PR #217.
fn tokio_runtime() -> &'static tokio::runtime::Runtime {
    static RUNTIME: std::sync::OnceLock<tokio::runtime::Runtime> = std::sync::OnceLock::new();
    RUNTIME.get_or_init(|| {
        tokio::runtime::Builder::new_multi_thread()
            .thread_name("zenohex-forwarder")
            .enable_all()
            .build()
            .expect("failed to build zenohex forwarder tokio runtime")
    })
}

