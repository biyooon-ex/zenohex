use std::collections::HashMap;
use std::sync::{LazyLock, Mutex};

use zenoh::Wait;

pub static SUBSCRIBERS: LazyLock<
    Mutex<HashMap<zenoh::session::EntityGlobalId, zenoh::pubsub::Subscriber<()>>>,
> = LazyLock::new(|| Mutex::new(HashMap::new()));

pub struct ZenohSubscriberId(pub zenoh::session::EntityGlobalId);
#[rustler::resource_impl]
impl rustler::Resource for ZenohSubscriberId {}
// NOTE: Release the Zenoh subscriber when the Elixir process holding the ZenohSubscriberId terminates.
impl Drop for ZenohSubscriberId {
    fn drop(&mut self) {
        let mut subscribers = SUBSCRIBERS.lock().unwrap();
        if let Some(subscriber) = subscribers.remove(&self.0) {
            let _ = subscriber.undeclare().wait();
        };
    }
}
