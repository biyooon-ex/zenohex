use std::collections::HashMap;
use std::sync::{LazyLock, Mutex};

use zenoh::Wait;

pub static PUBLISHERS: LazyLock<
    Mutex<HashMap<zenoh::session::EntityGlobalId, zenoh::pubsub::Publisher>>,
> = LazyLock::new(|| Mutex::new(HashMap::new()));

pub struct ZenohPublisherId(pub zenoh::session::EntityGlobalId);
#[rustler::resource_impl]
impl rustler::Resource for ZenohPublisherId {}

#[rustler::nif]
fn publisher_put(
    zenoh_publisher_id_resource: rustler::ResourceArc<ZenohPublisherId>,
    payload: &str,
) -> rustler::NifResult<rustler::Atom> {
    let publishers = PUBLISHERS.lock().unwrap();
    match publishers.get(&zenoh_publisher_id_resource.0) {
        Some(publisher) => match publisher.put(payload).wait() {
            Ok(_) => Ok(rustler::types::atom::ok()),
            Err(error) => Err(rustler::Error::Term(Box::new(error.to_string()))),
        },
        None => {
            let reason = "publisher not found".to_string();
            Err(rustler::Error::Term(Box::new(reason)))
        }
    }
}
