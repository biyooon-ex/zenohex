use std::collections::HashMap;
use std::sync::{LazyLock, Mutex};
use std::time::Duration;

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
    encoding: &str,
) -> rustler::NifResult<rustler::Atom> {
    let map = SESSIONS.lock().unwrap();
    match map.get(&zenoh_id_resource.0) {
        Some(session) => match session.put(key_expr, payload).encoding(encoding).wait() {
            Ok(_) => Ok(rustler::types::atom::ok()),
            Err(error) => Err(rustler::Error::Term(Box::new(error.to_string()))),
        },
        None => {
            let reason = "session not found".to_string();
            Err(rustler::Error::Term(Box::new(reason)))
        }
    }
}

#[rustler::nif(schedule = "DirtyIo")]
fn session_get<'a>(
    env: rustler::Env<'a>,
    zenoh_id_resource: rustler::ResourceArc<ZenohSessionId>,
    selector: &'a str,
    timeout: u64,
) -> Result<crate::sample::ZenohexSample<'a>, rustler::Term<'a>> {
    let map = SESSIONS.lock().unwrap();
    match map.get(&zenoh_id_resource.0) {
        Some(session) => match session.get(selector).wait() {
            Ok(fifo_channel_handler) => {
                match fifo_channel_handler.recv_timeout(Duration::from_millis(timeout)) {
                    Ok(option_reply) => {
                        if let Some(reply) = option_reply {
                            match reply.result() {
                                Ok(sample) => Ok(crate::sample::ZenohexSample::from(env, sample)),
                                Err(reply_error) => {
                                    Err(crate::query::ZenohexQueryReplyError::from(
                                        env,
                                        reply_error.clone(),
                                    )
                                    .encode(env))
                                }
                            }
                        } else {
                            Err("timeout".to_string().encode(env))
                        }
                    }
                    Err(error) => Err(error.to_string().encode(env)),
                }
            }
            Err(error) => Err(error.to_string().encode(env)),
        },
        None => Err("session not found".to_string().encode(env)),
    }
}

#[rustler::nif]
fn session_declare_publisher(
    zenoh_id_resource: rustler::ResourceArc<ZenohSessionId>,
    key_expr: String,
    encoding: &str,
) -> rustler::NifResult<(
    rustler::Atom,
    rustler::ResourceArc<crate::publisher::ZenohPublisherId>,
)> {
    let map = SESSIONS.lock().unwrap();
    match map.get(&zenoh_id_resource.0) {
        Some(session) => match session
            .declare_publisher(key_expr)
            .encoding(encoding)
            .wait()
        {
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
                        crate::sample::ZenohexSample::from(env, &sample)
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

#[rustler::nif]
fn session_declare_queryable(
    zenoh_id_resource: rustler::ResourceArc<ZenohSessionId>,
    key_expr: String,
    pid: rustler::LocalPid,
) -> rustler::NifResult<(
    rustler::Atom,
    rustler::ResourceArc<crate::queryable::ZenohQueryableId>,
)> {
    let map = SESSIONS.lock().unwrap();
    match map.get(&zenoh_id_resource.0) {
        Some(session) => match session
            .declare_queryable(key_expr)
            .callback(move |query| {
                // WHY: Spawn a thread inside this callback.
                //      If we don't spawn a thread, a panic will occur.
                //      See: https://docs.rs/rustler/latest/rustler/env/struct.OwnedEnv.html#panics
                std::thread::spawn(move || {
                    let mut owned_env = rustler::OwnedEnv::new();
                    let _ = owned_env
                        .send_and_clear(&pid, |env| crate::query::ZenohexQuery::from(env, query));
                });
            })
            .wait()
        {
            Ok(queryable) => {
                let mut queryables = crate::queryable::QUERYABLES.lock().unwrap();
                let queryable_id = queryable.id();
                queryables.insert(queryable_id, queryable);
                Ok((
                    rustler::types::atom::ok(),
                    rustler::ResourceArc::new(crate::queryable::ZenohQueryableId(queryable_id)),
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
