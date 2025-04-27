use std::collections::HashMap;
use std::io::Write;
use std::sync::{LazyLock, Mutex};

use rustler::Encoder;
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
// NOTE: Release the Zenoh session when the Elixir process holding the ZenohSessionId terminates.
impl Drop for ZenohSessionId {
    fn drop(&mut self) {
        let mut sessions = SESSIONS.lock().unwrap();
        if let Some(session) = sessions.remove(&self.0) {
            let _ = session.close().wait();
        };
    }
}

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

#[rustler::nif]
fn session_put(
    zenoh_id_resource: rustler::ResourceArc<ZenohSessionId>,
    key_expr: &str,
    payload: &str,
) -> rustler::NifResult<rustler::Atom> {
    let map = SESSIONS.lock().unwrap();
    match map.get(&zenoh_id_resource.0) {
        Some(session) => match session.put(key_expr, payload).wait() {
            Ok(_) => Ok(rustler::types::atom::ok()),
            Err(error) => Err(rustler::Error::Term(Box::new(error.to_string()))),
        },
        None => {
            let reason = "session not found".to_string();
            Err(rustler::Error::Term(Box::new(reason)))
        }
    }
}

#[rustler::nif]
fn session_declare_publisher(
    zenoh_id_resource: rustler::ResourceArc<ZenohSessionId>,
    key_expr: String,
) -> rustler::NifResult<(
    rustler::Atom,
    rustler::ResourceArc<crate::publisher::ZenohPublisherId>,
)> {
    let map = SESSIONS.lock().unwrap();
    match map.get(&zenoh_id_resource.0) {
        Some(session) => match session.declare_publisher(key_expr).wait() {
            Ok(publisher) => {
                let mut publishers = crate::publisher::PUBLISHERS.lock().unwrap();
                let publisher_id = publisher.id();
                publishers.insert(publisher_id, publisher);
                Ok((
                    rustler::types::atom::ok(),
                    rustler::ResourceArc::new(crate::publisher::ZenohPublisherId(publisher_id)),
                ))
            }
            Err(error) => Err(rustler::Error::Term(Box::new(error.to_string()))),
        },
        None => {
            let reason = "session not found".to_string();
            Err(rustler::Error::Term(Box::new(reason)))
        }
    }
}

#[rustler::nif]
fn session_declare_subscriber(
    zenoh_id_resource: rustler::ResourceArc<ZenohSessionId>,
    key_expr: String,
    pid: rustler::LocalPid,
) -> rustler::NifResult<(
    rustler::Atom,
    rustler::ResourceArc<crate::subscriber::ZenohSubscriberId>,
)> {
    let map = SESSIONS.lock().unwrap();
    match map.get(&zenoh_id_resource.0) {
        Some(session) => match session
            .declare_subscriber(key_expr)
            .callback(move |sample| {
                // WHY: Spawn a thread inside this callback.
                //      If we don't spawn a thread, a panic will occur.
                //      See: https://docs.rs/rustler/latest/rustler/env/struct.OwnedEnv.html#panics
                std::thread::spawn(move || {
                    let mut owned_env = rustler::OwnedEnv::new();
                    let _ = owned_env.send_and_clear(&pid, |env| {
                        let key_expr = sample.key_expr();
                        let payload = sample.payload();

                        let mut key_expr_binary =
                            rustler::OwnedBinary::new(key_expr.len()).unwrap();
                        key_expr_binary
                            .as_mut_slice()
                            .write_all(key_expr.as_str().as_bytes())
                            .unwrap();

                        let mut payload_binary = rustler::OwnedBinary::new(payload.len()).unwrap();
                        payload_binary
                            .as_mut_slice()
                            .write_all(&payload.to_bytes())
                            .unwrap();

                        (
                            crate::atoms::zenohex_nif(),
                            key_expr_binary.release(env),
                            payload_binary.release(env),
                        )
                            .encode(env)
                    });
                });
            })
            .wait()
        {
            Ok(subscriber) => {
                let mut subscribers = crate::subscriber::SUBSCRIBERS.lock().unwrap();
                let subscriber_id = subscriber.id();
                subscribers.insert(subscriber_id, subscriber);
                Ok((
                    rustler::types::atom::ok(),
                    rustler::ResourceArc::new(crate::subscriber::ZenohSubscriberId(subscriber_id)),
                ))
            }
            Err(error) => Err(rustler::Error::Term(Box::new(error.to_string()))),
        },
        None => {
            let reason = "session not found".to_string();
            Err(rustler::Error::Term(Box::new(reason)))
        }
    }
}
