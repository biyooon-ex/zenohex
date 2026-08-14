/// Channel capacity for `fifo_channel()`. Bounds only the native-side queue between
/// Zenoh callback threads and the forwarder; `send_and_clear` does not wait for the
/// BEAM process to consume its mailbox, so a slow/stuck consumer can still grow that
/// mailbox unbounded regardless of this value.
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
}
