use std::collections::HashMap;
use std::sync::{LazyLock, Mutex};

use zenoh::Wait;

pub static SUBSCRIBER_MAP: LazyLock<
    Mutex<HashMap<zenoh::session::EntityGlobalId, zenoh::pubsub::Subscriber<()>>>,
> = LazyLock::new(|| Mutex::new(HashMap::new()));

pub struct ZenohSubscriberId(pub zenoh::session::EntityGlobalId);
#[rustler::resource_impl]
impl rustler::Resource for ZenohSubscriberId {}

#[rustler::nif]
fn subscriber_undeclare(
    zenoh_subscriber_id_resource: rustler::ResourceArc<ZenohSubscriberId>,
) -> rustler::NifResult<rustler::Atom> {
    let subscriber_id = zenoh_subscriber_id_resource.0;
    let mut map = SUBSCRIBER_MAP.lock().unwrap();

    let subscriber = map
        .remove(&subscriber_id)
        .ok_or_else(|| rustler::Error::Term(Box::new("subscriber not found")))?;

    subscriber
        .undeclare()
        .wait()
        .map_err(|error| rustler::Error::Term(Box::new(error.to_string())))?;

    Ok(rustler::types::atom::ok())
}
