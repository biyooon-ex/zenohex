use std::collections::HashMap;
use std::sync::{LazyLock, Mutex};

pub static SUBSCRIBERS: LazyLock<
    Mutex<HashMap<zenoh::session::EntityGlobalId, zenoh::pubsub::Subscriber<()>>>,
> = LazyLock::new(|| Mutex::new(HashMap::new()));

pub struct ZenohSubscriberId(pub zenoh::session::EntityGlobalId);
#[rustler::resource_impl]
impl rustler::Resource for ZenohSubscriberId {}
