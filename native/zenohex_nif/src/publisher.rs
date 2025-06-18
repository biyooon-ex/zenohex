use std::collections::HashMap;
use std::sync::{LazyLock, Mutex};

use zenoh::Wait;

pub static PUBLISHERS: LazyLock<
    Mutex<HashMap<zenoh::session::EntityGlobalId, zenoh::pubsub::Publisher>>,
> = LazyLock::new(|| Mutex::new(HashMap::new()));

pub struct ZenohPublisherId(pub zenoh::session::EntityGlobalId);
#[rustler::resource_impl]
impl rustler::Resource for ZenohPublisherId {}

rustler::atoms! {
    encoding,
}

#[rustler::nif]
fn publisher_put(
    zenoh_publisher_id_resource: rustler::ResourceArc<ZenohPublisherId>,
    payload: &str,
) -> rustler::NifResult<rustler::Atom> {
    let publishers = PUBLISHERS.lock().unwrap();
    let publisher_id = zenoh_publisher_id_resource.0;

    let publisher = publishers
        .get(&publisher_id)
        .ok_or_else(|| rustler::Error::Term(Box::new("publisher not found")))?;

    publisher
        .put(payload)
        .wait()
        .map_err(|error| rustler::Error::Term(Box::new(error.to_string())))?;

    Ok(rustler::types::atom::ok())
}
