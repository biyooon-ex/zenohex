use std::collections::HashMap;
use std::sync::{LazyLock, Mutex};

use zenoh::Wait;

static SESSIONS: LazyLock<Mutex<HashMap<zenoh::session::ZenohId, zenoh::Session>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

// WHY: Use zenoh::session::ZenohId for resource, instead of zenoh::Session itself
//      If we use the session for resource, we got the following error.
//      the trait std::panic::RefUnwindSafe is not implemented for
//      std::cell::UnsafeCell<std::collections::HashSet<zenoh_protocol::core::ZenohIdProto>>
struct ZenohSessionId(zenoh::session::ZenohId);
#[rustler::resource_impl]
impl rustler::Resource for ZenohSessionId {}

#[rustler::nif]
fn session_open(
    json5_binary: &str,
) -> rustler::NifResult<(rustler::Atom, rustler::ResourceArc<ZenohSessionId>)> {
    match zenoh::Config::from_json5(json5_binary) {
        Ok(config) => match zenoh::open(config).wait() {
            Ok(session) => {
                let mut map = SESSIONS.lock().unwrap();
                let zenoh_id = session.zid();
                map.insert(zenoh_id, session);
                Ok((
                    rustler::types::atom::ok(),
                    rustler::ResourceArc::new(ZenohSessionId(zenoh_id)),
                ))
            }
            Err(error) => {
                let reason = error.to_string();
                Err(rustler::Error::Term(Box::new(reason)))
            }
        },
        Err(error) => {
            let reason = error.to_string();
            Err(rustler::Error::Term(Box::new(reason)))
        }
    }
}

#[rustler::nif]
fn session_close(
    zenoh_id_resource: rustler::ResourceArc<ZenohSessionId>,
) -> rustler::NifResult<rustler::Atom> {
    let mut map = SESSIONS.lock().unwrap();
    match map.remove(&zenoh_id_resource.0) {
        Some(session) => {
            let _ = session.close().wait();
            Ok(rustler::types::atom::ok())
        }
        None => {
            let reason = "session not found".to_string();
            Err(rustler::Error::Term(Box::new(reason)))
        }
    }
}
