use std::collections::HashMap;
use std::sync::Arc;
use std::sync::LazyLock;
use std::sync::RwLock;
use std::time::Duration;
use std::time::Instant;

use rustler::Encoder;
use zenoh::Wait;

pub(crate) enum Entity<'a> {
    Publisher(
        zenoh::pubsub::Publisher<'a>,
        #[allow(dead_code)] rustler::ResourceArc<SessionIdResource>,
    ),
    Subscriber(
        zenoh::pubsub::Subscriber<()>,
        #[allow(dead_code)] rustler::ResourceArc<SessionIdResource>,
    ),
    Queryable(
        zenoh::query::Queryable<()>,
        #[allow(dead_code)] rustler::ResourceArc<SessionIdResource>,
    ),
}

pub(crate) struct Session<'a> {
    inner: zenoh::Session,
    pub(crate) entities: HashMap<zenoh::session::EntityGlobalId, Entity<'a>>,
}

impl<'a> Session<'a> {
    fn insert_entity(
        &mut self,
        entity_id: zenoh::session::EntityGlobalId,
        entity: Entity<'a>,
    ) -> rustler::NifResult<rustler::Atom> {
        match self.entities.insert(entity_id, entity) {
            Some(_entity) => Err(rustler::Error::Term(Box::new("entity already existed"))),
            None => Ok(rustler::types::atom::ok()),
        }
    }

    pub(crate) fn get_entity(
        &self,
        entity_id: &zenoh::session::EntityGlobalId,
    ) -> rustler::NifResult<&Entity> {
        self.entities
            .get(entity_id)
            .ok_or_else(|| rustler::Error::Term(Box::new("entity not found")))
    }

    pub(crate) fn remove_entity(
        &mut self,
        entity_id: &zenoh::session::EntityGlobalId,
    ) -> rustler::NifResult<Entity> {
        self.entities
            .remove(entity_id)
            .ok_or_else(|| rustler::Error::Term(Box::new("entity not found")))
    }
}

pub(crate) struct SessionMap<'a>(
    RwLock<HashMap<zenoh::session::ZenohId, Arc<RwLock<Session<'a>>>>>,
);

impl<'a> SessionMap<'_> {
    fn new() -> SessionMap<'a> {
        SessionMap(RwLock::new(HashMap::new()))
    }

    fn insert_session(
        session_map: &SessionMap,
        session_id: zenoh::session::ZenohId,
        session: zenoh::Session,
    ) -> rustler::NifResult<rustler::Atom> {
        let mut map = session_map.0.write().unwrap();
        match map.insert(
            session_id,
            Arc::new(RwLock::new(Session {
                inner: session,
                entities: HashMap::new(),
            })),
        ) {
            Some(_) => Err(rustler::Error::Term(Box::new("session already existed"))),
            None => Ok(rustler::types::atom::ok()),
        }
    }

    pub(crate) fn get_session(
        session_map: &'a SessionMap<'a>,
        session_id: &zenoh::session::ZenohId,
    ) -> rustler::NifResult<Arc<RwLock<Session<'a>>>> {
        let map = session_map.0.read().unwrap();
        map.get(session_id)
            .cloned()
            .ok_or_else(|| rustler::Error::Term(Box::new("session not found")))
    }

    fn remove_session(
        session_map: &'a SessionMap<'a>,
        session_id: &zenoh::session::ZenohId,
    ) -> rustler::NifResult<Arc<RwLock<Session<'a>>>> {
        let mut map = session_map.0.write().unwrap();
        map.remove(session_id)
            .ok_or_else(|| rustler::Error::Term(Box::new("session not found")))
    }
}

pub(crate) static SESSION_MAP: LazyLock<SessionMap> = LazyLock::new(SessionMap::new);

// WHY: Use zenoh::session::ZenohId for resource, instead of zenoh::Session itself
//      If we use the session for resource, we got the following error.
//      the trait std::panic::RefUnwindSafe is not implemented for
//      std::cell::UnsafeCell<std::collections::HashSet<zenoh_protocol::core::ZenohIdProto>>
pub(crate) struct SessionIdResource(zenoh::session::ZenohId);

#[rustler::resource_impl]
impl rustler::Resource for SessionIdResource {}

impl Drop for SessionIdResource {
    fn drop(&mut self) {
        let session_id = &self.0;
        match SessionMap::remove_session(&SESSION_MAP, session_id) {
            Ok(session) => {
                let locked_session = session.write().unwrap();
                if locked_session.inner.is_closed() {
                    crate::helper::logger::logger_debug("session already closed.")
                } else {
                    locked_session.inner.close().wait().unwrap();
                    crate::helper::logger::logger_debug("session closed by drop.")
                }
            }
            Err(_error) => crate::helper::logger::logger_debug("session already removed."),
        }
    }
}

#[derive(Hash)]
pub(crate) struct EntityIdResource(pub(crate) zenoh::session::EntityGlobalId);

impl EntityIdResource {
    fn new(entity_id: zenoh::session::EntityGlobalId) -> EntityIdResource {
        EntityIdResource(entity_id)
    }
}

#[rustler::resource_impl]
impl rustler::Resource for EntityIdResource {}

mod atoms {
    rustler::atoms! {
        attachment,
    }
}

#[rustler::nif]
fn session_open(
    json5_binary: &str,
) -> rustler::NifResult<(rustler::Atom, rustler::ResourceArc<SessionIdResource>)> {
    let config = zenoh::Config::from_json5(json5_binary)
        .map_err(|error| rustler::Error::Term(Box::new(error.to_string())))?;

    let session = zenoh::open(config)
        .wait()
        .map_err(|error| rustler::Error::Term(Box::new(error.to_string())))?;

    let session_id = session.zid();

    SessionMap::insert_session(&SESSION_MAP, session_id, session)?;

    Ok((
        rustler::types::atom::ok(),
        rustler::ResourceArc::new(SessionIdResource(session_id)),
    ))
}

#[rustler::nif]
fn session_close(
    session_id_resource: rustler::ResourceArc<SessionIdResource>,
) -> rustler::NifResult<rustler::Atom> {
    let session_id = &session_id_resource.0;
    let session = SessionMap::remove_session(&SESSION_MAP, session_id)?;
    let locked_session = session.write().unwrap();

    locked_session
        .inner
        .close()
        .wait()
        .map_err(|error| rustler::Error::Term(Box::new(error.to_string())))?;

    Ok(rustler::types::atom::ok())
}

#[rustler::nif]
fn session_put(
    session_id_resource: rustler::ResourceArc<SessionIdResource>,
    key_expr: &str,
    payload: &str,
    opts: rustler::Term,
) -> rustler::NifResult<rustler::Atom> {
    let session_id = &session_id_resource.0;
    let session = SessionMap::get_session(&SESSION_MAP, session_id)?;
    let locked_session = session.read().unwrap();

    let mut opts_iter: rustler::ListIterator = opts.decode()?;

    let publication_builder = locked_session.inner.put(key_expr, payload);

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
    session_id_resource: rustler::ResourceArc<SessionIdResource>,
    selector: &'a str,
    timeout: u64,
    opts: rustler::Term,
) -> rustler::NifResult<(rustler::Atom, Vec<rustler::Term<'a>>)> {
    let session_id = &session_id_resource.0;
    let session = SessionMap::get_session(&SESSION_MAP, session_id)?;
    let locked_session = session.read().unwrap();

    let mut opts_iter: rustler::ListIterator = opts.decode()?;

    let session_get_builder = locked_session.inner.get(selector);

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
    session_id_resource: rustler::ResourceArc<SessionIdResource>,
    key_expr: String,
    opts: rustler::Term,
) -> rustler::NifResult<(rustler::Atom, rustler::ResourceArc<EntityIdResource>)> {
    let session_id = &session_id_resource.0;
    let session = SessionMap::get_session(&SESSION_MAP, session_id)?;
    let mut locked_session = session.write().unwrap();
    let mut opts_iter: rustler::ListIterator = opts.decode()?;

    let publisher_builder = locked_session.inner.declare_publisher(key_expr);
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
    let publisher_id = publisher.id();
    locked_session.insert_entity(
        publisher_id,
        Entity::Publisher(publisher, session_id_resource),
    )?;

    Ok((
        rustler::types::atom::ok(),
        rustler::ResourceArc::new(EntityIdResource::new(publisher_id)),
    ))
}

#[rustler::nif]
fn session_declare_subscriber(
    session_id_resource: rustler::ResourceArc<SessionIdResource>,
    key_expr: String,
    // WHY: Pass `pid` instead of using `env.pid()`
    //      so the user can specify any receiver process
    pid: rustler::LocalPid,
) -> rustler::NifResult<(rustler::Atom, rustler::ResourceArc<EntityIdResource>)> {
    let session_id = &session_id_resource.0;
    let session = SessionMap::get_session(&SESSION_MAP, session_id)?;
    let mut locked_session = session.write().unwrap();

    let subscriber = locked_session
        .inner
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

    let subscriber_id = subscriber.id();
    locked_session.insert_entity(
        subscriber_id,
        Entity::Subscriber(subscriber, session_id_resource),
    )?;

    Ok((
        rustler::types::atom::ok(),
        rustler::ResourceArc::new(EntityIdResource::new(subscriber_id)),
    ))
}

#[rustler::nif]
fn session_declare_queryable(
    session_id_resource: rustler::ResourceArc<SessionIdResource>,
    key_expr: String,
    // WHY: Pass `pid` instead of using `env.pid()`
    //      so the user can specify any receiver process
    pid: rustler::LocalPid,
) -> rustler::NifResult<(rustler::Atom, rustler::ResourceArc<EntityIdResource>)> {
    let session_id = &session_id_resource.0;
    let session = SessionMap::get_session(&SESSION_MAP, session_id)?;
    let mut locked_session = session.write().unwrap();

    let queryable = locked_session
        .inner
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

    let queryable_id = queryable.id();
    locked_session.insert_entity(
        queryable_id,
        Entity::Queryable(queryable, session_id_resource),
    )?;

    Ok((
        rustler::types::atom::ok(),
        rustler::ResourceArc::new(EntityIdResource::new(queryable_id)),
    ))
}
