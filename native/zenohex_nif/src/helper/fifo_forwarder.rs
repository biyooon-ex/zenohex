/// Channel capacity for `fifo_channel()`. Bounded so a slow BEAM consumer applies
/// backpressure to Zenoh's callback threads instead of growing memory unbounded.
const CHANNEL_CAPACITY: usize = 256;

/// Build the handler used to receive callback items in FIFO order.
pub fn fifo_channel() -> zenoh::handlers::FifoChannel {
    zenoh::handlers::FifoChannel::new(CHANNEL_CAPACITY)
}

// WHY: Zenoh may invoke callbacks from multiple worker threads. Sending directly from
//      each callback thread via a fresh `OwnedEnv` races with other callback threads
//      targeting the same pid and can reorder deliveries. Draining `handler` from a
//      single dedicated thread and reusing one `OwnedEnv` preserves delivery order and
//      keeps `send_and_clear` allocations low.
//
// WHY panic isolation matters: unlike the previous one-thread-per-message design, a
//      panic here would stop delivery for the entire lifetime of this entity, so any
//      `encode` closure passed in must not panic on malformed input.
pub fn spawn_forwarder<T, F>(
    pid: rustler::LocalPid,
    handler: zenoh::handlers::FifoChannelHandler<T>,
    encode: F,
) where
    T: Send + 'static,
    F: for<'a> Fn(rustler::Env<'a>, T) -> rustler::Term<'a> + Send + 'static,
{
    std::thread::spawn(move || {
        let mut owned_env = rustler::OwnedEnv::new();
        for item in handler.iter() {
            let _ = owned_env.send_and_clear(&pid, |env| encode(env, item));
        }
    });
}
