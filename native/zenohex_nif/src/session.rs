use std::collections::HashMap;
use std::sync::{Arc, LazyLock, Mutex};
use std::time::{Duration, Instant};

use rustler::Encoder;
use zenoh::Wait;

type SessionMap = LazyLock<Arc<Mutex<HashMap<zenoh::session::ZenohId, zenoh::Session>>>>;

static SESSION_MAP: SessionMap = LazyLock::new(|| Arc::new(Mutex::new(HashMap::new())));

// WHY: Use zenoh::session::ZenohId for resource, instead of zenoh::Session itself
//      If we use the session for resource, we got the following error.
//      the trait std::panic::RefUnwindSafe is not implemented for
//      std::cell::UnsafeCell<std::collections::HashSet<zenoh_protocol::core::ZenohIdProto>>
struct ZenohSessionId(zenoh::session::ZenohId);
#[rustler::resource_impl]
impl rustler::Resource for ZenohSessionId {}

mod atoms {
    rustler::atoms! {
        attachment,
    }
}

#[rustler::nif]
fn session_open(
    json5_binary: &str,
) -> rustler::NifResult<(rustler::Atom, rustler::ResourceArc<ZenohSessionId>)> {
    let config = zenoh::Config::from_json5(json5_binary)
        .map_err(|error| rustler::Error::Term(Box::new(error.to_string())))?;

    let session = zenoh::open(config)
        .wait()
        .map_err(|error| rustler::Error::Term(Box::new(error.to_string())))?;

    let session_id = session.zid();

    insert_session(session_id, session)?;

    Ok((
        rustler::types::atom::ok(),
        rustler::ResourceArc::new(ZenohSessionId(session_id)),
    ))
}

#[rustler::nif]
fn session_close(
    zenoh_session_id_resource: rustler::ResourceArc<ZenohSessionId>,
) -> rustler::NifResult<rustler::Atom> {
    let session_id = &zenoh_session_id_resource.0;
    let session = remove_session(session_id)?;

    session
        .close()
        .wait()
        .map_err(|error| rustler::Error::Term(Box::new(error.to_string())))?;

    Ok(rustler::types::atom::ok())
}

#[rustler::nif]
fn session_put(
    zenoh_session_id_resource: rustler::ResourceArc<ZenohSessionId>,
    key_expr: &str,
    payload: &str,
    opts: rustler::Term,
) -> rustler::NifResult<rustler::Atom> {
    let session_id = &zenoh_session_id_resource.0;
    let session = get_session(session_id)?;

    let mut opts_iter: rustler::ListIterator = opts.decode()?;

    let publication_builder = session.put(key_expr, payload);

    let publication_builder = opts_iter.try_fold(publication_builder, |builder, opt| {
        let (k, v): (rustler::Atom, rustler::Term) = opt.decode()?;
        match k {
            k if k == crate::publisher::atoms::encoding() => {
                let encoding: &str = v.decode()?;
                Ok(builder.encoding(encoding))
            }
            _ => Ok(builder),
        }
    })?;

    publication_builder
        .wait()
        .map_err(|error| rustler::Error::Term(Box::new(error.to_string())))?;

    Ok(rustler::types::atom::ok())
}

#[rustler::nif(schedule = "DirtyIo")]
fn session_get<'a>(
    env: rustler::Env<'a>,
    zenoh_session_id_resource: rustler::ResourceArc<ZenohSessionId>,
    selector: &'a str,
    timeout: u64,
    opts: rustler::Term,
) -> rustler::NifResult<(rustler::Atom, Vec<rustler::Term<'a>>)> {
    let session_id = &zenoh_session_id_resource.0;
    let session = get_session(session_id)?;

    let mut opts_iter: rustler::ListIterator = opts.decode()?;

    let session_get_builder = session.get(selector);

    let session_get_builder = opts_iter.try_fold(session_get_builder, |builder, opt| {
        let (k, v): (rustler::Atom, rustler::Term) = opt.decode()?;
        match k {
            k if k == crate::session::atoms::attachment() => {
                if let Some(payload) = v.decode::<Option<&str>>()? {
                    Ok(builder.attachment(payload))
                } else {
                    Ok(builder)
                }
            }
            _ => Ok(builder),
        }
    })?;

    let channel_handler = session_get_builder
        .wait()
        .map_err(|error| rustler::Error::Term(Box::new(error.to_string())))?;

    let deadline = Instant::now() + Duration::from_millis(timeout);
    let mut replies = Vec::new();

    loop {
        // NOTE: `recv_deadline` document says following,
        //       > If the deadline has expired, this will return None.
        let option_reply = channel_handler
            .recv_deadline(deadline)
            .map_err(|error| rustler::Error::Term(Box::new(error.to_string())))?;

        let Some(reply) = option_reply else {
            // the deadline has expired
            return Err(rustler::Error::Term(Box::new("timeout")));
        };

        let term = match reply.result() {
            Ok(sample) => crate::sample::ZenohexSample::from(env, sample).encode(env),
            Err(reply_error) => {
                crate::query::ZenohexQueryReplyError::from(env, reply_error).encode(env)
            }
        };

        replies.push(term);

        if channel_handler.is_empty() {
            break;
        }
    }

    Ok((rustler::types::atom::ok(), replies))
}

#[rustler::nif]
fn session_declare_publisher(
    zenoh_session_id_resource: rustler::ResourceArc<ZenohSessionId>,
    key_expr: String,
    opts: rustler::Term,
) -> rustler::NifResult<(
    rustler::Atom,
    rustler::ResourceArc<crate::publisher::ZenohPublisherId>,
)> {
    let session_id = &zenoh_session_id_resource.0;
    let session = get_session(session_id)?;

    let mut opts_iter: rustler::ListIterator = opts.decode()?;

    let publisher_builder = session.declare_publisher(key_expr);

    let publisher_builder = opts_iter.try_fold(publisher_builder, |builder, opt| {
        let (k, v): (rustler::Atom, rustler::Term) = opt.decode()?;
        match k {
            k if k == crate::publisher::atoms::encoding() => {
                let encoding: &str = v.decode()?;
                Ok(builder.encoding(encoding))
            }
            _ => Ok(builder),
        }
    })?;

    let publisher = publisher_builder
        .wait()
        .map_err(|error| rustler::Error::Term(Box::new(error.to_string())))?;

    let mut publishers = crate::publisher::PUBLISHERS.lock().unwrap();
    let publisher_id = publisher.id();
    publishers.insert(publisher_id, publisher);

    Ok((
        rustler::types::atom::ok(),
        rustler::ResourceArc::new(crate::publisher::ZenohPublisherId(publisher_id)),
    ))
}

#[rustler::nif]
fn session_declare_subscriber(
    zenoh_session_id_resource: rustler::ResourceArc<ZenohSessionId>,
    key_expr: String,
    // WHY: Pass `pid` instead of using `env.pid()`
    //      so the user can specify any receiver process
    pid: rustler::LocalPid,
) -> rustler::NifResult<(
    rustler::Atom,
    rustler::ResourceArc<crate::subscriber::ZenohSubscriberId>,
)> {
    let session_id = &zenoh_session_id_resource.0;
    let session = get_session(session_id)?;

    let subscriber = session
        .declare_subscriber(key_expr)
        .callback(move |sample| {
            // WHY: Spawn a thread inside this callback.
            //      If we don't spawn a thread, a panic will occur.
            //      See: https://docs.rs/rustler/latest/rustler/env/struct.OwnedEnv.html#panics
            std::thread::spawn(move || {
                let _ = rustler::OwnedEnv::new().run(|env: rustler::Env| {
                    env.send(&pid, crate::sample::ZenohexSample::from(env, &sample))
                });
            });
        })
        .wait()
        .map_err(|error| rustler::Error::Term(Box::new(error.to_string())))?;

    let mut subscribers = crate::subscriber::SUBSCRIBERS.lock().unwrap();
    let subscriber_id = subscriber.id();
    subscribers.insert(subscriber_id, subscriber);

    Ok((
        rustler::types::atom::ok(),
        rustler::ResourceArc::new(crate::subscriber::ZenohSubscriberId(subscriber_id)),
    ))
}

#[rustler::nif]
fn session_declare_queryable(
    zenoh_session_id_resource: rustler::ResourceArc<ZenohSessionId>,
    key_expr: String,
    // WHY: Pass `pid` instead of using `env.pid()`
    //      so the user can specify any receiver process
    pid: rustler::LocalPid,
) -> rustler::NifResult<(
    rustler::Atom,
    rustler::ResourceArc<crate::queryable::ZenohQueryableId>,
)> {
    let session_id = &zenoh_session_id_resource.0;
    let session = get_session(session_id)?;

    let queryable = session
        .declare_queryable(key_expr)
        .callback(move |query| {
            // WHY: Spawn a thread inside this callback.
            //      If we don't spawn a thread, a panic will occur.
            //      See: https://docs.rs/rustler/latest/rustler/env/struct.OwnedEnv.html#panics
            std::thread::spawn(move || {
                let _ = rustler::OwnedEnv::new().run(|env: rustler::Env| {
                    env.send(&pid, crate::query::ZenohexQuery::from(env, &query))
                });
            });
        })
        .wait()
        .map_err(|error| rustler::Error::Term(Box::new(error.to_string())))?;

    let mut queryables = crate::queryable::QUERYABLES.lock().unwrap();
    let queryable_id = queryable.id();
    queryables.insert(queryable_id, queryable);

    Ok((
        rustler::types::atom::ok(),
        rustler::ResourceArc::new(crate::queryable::ZenohQueryableId(queryable_id)),
    ))
}

fn insert_session(
    session_id: zenoh::session::ZenohId,
    session: zenoh::Session,
) -> rustler::NifResult<rustler::Atom> {
    SESSION_MAP
        .lock()
        .unwrap()
        .insert(session_id, session)
        .map_or_else(
            || Ok(rustler::types::atom::ok()),
            |_| Err(rustler::Error::Term(Box::new("session already inserted"))),
        )
}

fn get_session(session_id: &zenoh::session::ZenohId) -> rustler::NifResult<zenoh::Session> {
    SESSION_MAP
        .lock()
        .unwrap()
        .get(session_id)
        .cloned()
        .ok_or_else(|| rustler::Error::Term(Box::new("session not found")))
}

fn remove_session(session_id: &zenoh::session::ZenohId) -> rustler::NifResult<zenoh::Session> {
    SESSION_MAP
        .lock()
        .unwrap()
        .remove(session_id)
        .ok_or_else(|| rustler::Error::Term(Box::new("session not found")))
}
