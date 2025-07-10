use std::collections::HashMap;
use std::ops::Deref;
use std::sync::Arc;
use std::sync::LazyLock;
use std::sync::RwLock;
use std::time::Duration;
use std::time::Instant;

use rustler::Encoder;
use zenoh::Wait;

use crate::builder::Builder;

pub enum Entity<'a> {
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

pub struct Session<'a> {
    inner: zenoh::Session,
    entities: HashMap<zenoh::session::EntityGlobalId, Entity<'a>>,
}

impl<'a> Session<'a> {
    pub fn insert_entity(
        &mut self,
        entity_global_id: zenoh::session::EntityGlobalId,
        entity: Entity<'a>,
    ) -> rustler::NifResult<rustler::Atom> {
        match self.entities.insert(entity_global_id, entity) {
            Some(_entity) => Err(rustler::Error::Term(Box::new("entity already existed"))),
            None => Ok(rustler::types::atom::ok()),
        }
    }

    pub fn get_entity(
        &self,
        entity_global_id: &zenoh::session::EntityGlobalId,
    ) -> rustler::NifResult<&Entity> {
        self.entities
            .get(entity_global_id)
            .ok_or_else(|| rustler::Error::Term(Box::new("entity not found")))
    }

    pub fn remove_entity(
        &mut self,
        entity_global_id: &zenoh::session::EntityGlobalId,
    ) -> rustler::NifResult<Entity> {
        self.entities
            .remove(entity_global_id)
            .ok_or_else(|| rustler::Error::Term(Box::new("entity not found")))
    }
}

impl Deref for Session<'_> {
    type Target = zenoh::Session;

    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}

pub struct SessionMap<'a>(RwLock<HashMap<zenoh::session::ZenohId, Arc<RwLock<Session<'a>>>>>);

impl<'a> Deref for SessionMap<'a> {
    type Target = RwLock<HashMap<zenoh::session::ZenohId, Arc<RwLock<Session<'a>>>>>;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

impl<'a> SessionMap<'_> {
    fn new() -> SessionMap<'a> {
        SessionMap(RwLock::new(HashMap::new()))
    }

    fn insert_session(
        session_map: &SessionMap,
        session_id: zenoh::session::ZenohId,
        session: zenoh::Session,
    ) -> rustler::NifResult<rustler::Atom> {
        let mut map = session_map.write().unwrap();
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

    pub fn get_session(
        session_map: &'a SessionMap<'a>,
        session_id: &zenoh::session::ZenohId,
    ) -> rustler::NifResult<Arc<RwLock<Session<'a>>>> {
        let map = session_map.read().unwrap();
        map.get(session_id)
            .cloned()
            .ok_or_else(|| rustler::Error::Term(Box::new("session not found")))
    }

    fn remove_session(
        session_map: &'a SessionMap<'a>,
        session_id: &zenoh::session::ZenohId,
    ) -> rustler::NifResult<Arc<RwLock<Session<'a>>>> {
        let mut map = session_map.write().unwrap();
        map.remove(session_id)
            .ok_or_else(|| rustler::Error::Term(Box::new("session not found")))
    }
}

pub static SESSION_MAP: LazyLock<SessionMap> = LazyLock::new(SessionMap::new);

// WHY: Use zenoh::session::ZenohId for resource, instead of zenoh::Session itself
//      If we use the session for resource, we got the following error.
//      the trait std::panic::RefUnwindSafe is not implemented for
//      std::cell::UnsafeCell<std::collections::HashSet<zenoh_protocol::core::ZenohIdProto>>
pub struct SessionIdResource(zenoh::session::ZenohId);

#[rustler::resource_impl]
impl rustler::Resource for SessionIdResource {}
impl Deref for SessionIdResource {
    type Target = zenoh::session::ZenohId;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

impl Drop for SessionIdResource {
    fn drop(&mut self) {
        let session_id = &self.0;

        match SessionMap::remove_session(&SESSION_MAP, session_id) {
            Ok(session) => {
                let session_locked = session.write().unwrap();
                let message = if session_locked.is_closed() {
                    "session already closed."
                } else {
                    session_locked.close().wait().unwrap();
                    "session closed by drop."
                };
                log::debug!("{}", message)
            }
            Err(_error) => log::debug!(target: module_path!(), "session already removed."),
        };
    }
}

pub struct EntityGlobalIdResource(zenoh::session::EntityGlobalId);

#[rustler::resource_impl]
impl rustler::Resource for EntityGlobalIdResource {}

impl EntityGlobalIdResource {
    pub fn new(entity_global_id: zenoh::session::EntityGlobalId) -> EntityGlobalIdResource {
        EntityGlobalIdResource(entity_global_id)
    }
}

impl Deref for EntityGlobalIdResource {
    type Target = zenoh::session::EntityGlobalId;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

impl Drop for EntityGlobalIdResource {
    fn drop(&mut self) {
        let session_id = &self.0.zid();
        let entity_global_id = &self.0;

        if let Ok(session) = SessionMap::get_session(&SESSION_MAP, session_id) {
            let mut session_locked = session.write().unwrap();
            let result = session_locked.remove_entity(entity_global_id);
            let message = match result {
                Ok(_) => "entity removed by drop.",
                Err(_) => "entity already removed.",
            };
            log::debug!("{}", message);
        }
    }
}

#[rustler::nif]
fn session_open(
    json5_binary: &str,
) -> rustler::NifResult<(rustler::Atom, rustler::ResourceArc<SessionIdResource>)> {
    let config = zenoh::Config::from_json5(json5_binary)
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

    let session = zenoh::open(config)
        .wait()
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

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
    let session_id = &session_id_resource;
    let session = SessionMap::remove_session(&SESSION_MAP, session_id)?;
    let session_locked = session.write().unwrap();

    session_locked
        .close()
        .wait()
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

    Ok(rustler::types::atom::ok())
}

#[rustler::nif]
fn session_put(
    session_id_resource: rustler::ResourceArc<SessionIdResource>,
    key_expr: &str,
    payload: rustler::Binary,
    opts: rustler::Term,
) -> rustler::NifResult<rustler::Atom> {
    let session_id = &session_id_resource;
    let session = SessionMap::get_session(&SESSION_MAP, session_id)?;
    let session_locked = session.read().unwrap();
    let publication_builder = session_locked.put(key_expr, payload.as_slice());

    publication_builder
        .apply_opts(opts)?
        .wait()
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

    Ok(rustler::types::atom::ok())
}

#[rustler::nif]
fn session_delete(
    session_id_resource: rustler::ResourceArc<SessionIdResource>,
    key_expr: &str,
    opts: rustler::Term,
) -> rustler::NifResult<rustler::Atom> {
    let session_id = &session_id_resource;
    let session = SessionMap::get_session(&SESSION_MAP, session_id)?;
    let session_locked = session.read().unwrap();
    let publication_builder = session_locked.delete(key_expr);

    publication_builder
        .apply_opts(opts)?
        .wait()
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

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
    let session_id = &session_id_resource;
    let session = SessionMap::get_session(&SESSION_MAP, session_id)?;
    let session_locked = session.read().unwrap();
    let session_get_builder = session_locked.get(selector);

    let channel_handler = session_get_builder
        .apply_opts(opts)?
        .wait()
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

    let deadline = Instant::now() + Duration::from_millis(timeout);
    let mut replies = Vec::new();

    loop {
        // NOTE: `recv_deadline` document says following,
        //       > If the deadline has expired, this will return None.
        let option_reply = channel_handler
            .recv_deadline(deadline)
            .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

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
fn session_new_timestamp(
    session_id_resource: rustler::ResourceArc<SessionIdResource>,
) -> rustler::NifResult<(rustler::Atom, String)> {
    let session_id = &session_id_resource;
    let session = SessionMap::get_session(&SESSION_MAP, session_id)?;
    let session_locked = session.read().unwrap();
    let timestamp = session_locked.new_timestamp().to_string_rfc3339_lossy();

    Ok((rustler::types::atom::ok(), timestamp))
}

#[rustler::nif]
fn session_declare_publisher(
    session_id_resource: rustler::ResourceArc<SessionIdResource>,
    key_expr: String,
    opts: rustler::Term,
) -> rustler::NifResult<(rustler::Atom, rustler::ResourceArc<EntityGlobalIdResource>)> {
    let session_id = &session_id_resource;
    let session = SessionMap::get_session(&SESSION_MAP, session_id)?;
    let mut session_locked = session.write().unwrap();

    let publisher_builder = session_locked.declare_publisher(key_expr);

    let publisher = publisher_builder
        .apply_opts(opts)?
        .wait()
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

    let publisher_id = publisher.id();
    session_locked.insert_entity(
        publisher_id,
        Entity::Publisher(publisher, session_id_resource),
    )?;

    Ok((
        rustler::types::atom::ok(),
        rustler::ResourceArc::new(EntityGlobalIdResource::new(publisher_id)),
    ))
}

#[rustler::nif]
fn session_declare_subscriber(
    session_id_resource: rustler::ResourceArc<SessionIdResource>,
    key_expr: String,
    // WHY: Pass `pid` instead of using `env.pid()`
    //      so the user can specify any receiver process
    pid: rustler::LocalPid,
    opts: rustler::Term,
) -> rustler::NifResult<(rustler::Atom, rustler::ResourceArc<EntityGlobalIdResource>)> {
    let session_id = &session_id_resource;
    let session = SessionMap::get_session(&SESSION_MAP, session_id)?;
    let mut session_locked = session.write().unwrap();

    let subscriber_buidler = session_locked.declare_subscriber(key_expr);

    let subscriber = subscriber_buidler
        .apply_opts(opts)?
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
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

    let subscriber_id = subscriber.id();
    session_locked.insert_entity(
        subscriber_id,
        Entity::Subscriber(subscriber, session_id_resource),
    )?;

    Ok((
        rustler::types::atom::ok(),
        rustler::ResourceArc::new(EntityGlobalIdResource::new(subscriber_id)),
    ))
}

#[rustler::nif]
fn session_declare_queryable(
    session_id_resource: rustler::ResourceArc<SessionIdResource>,
    key_expr: String,
    // WHY: Pass `pid` instead of using `env.pid()`
    //      so the user can specify any receiver process
    pid: rustler::LocalPid,
    opts: rustler::Term,
) -> rustler::NifResult<(rustler::Atom, rustler::ResourceArc<EntityGlobalIdResource>)> {
    let session_id = &session_id_resource;
    let session = SessionMap::get_session(&SESSION_MAP, session_id)?;
    let mut session_locked = session.write().unwrap();

    let queryable_builder = session_locked.declare_queryable(key_expr);

    let queryable = queryable_builder
        .apply_opts(opts)?
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
        .map_err(|error| rustler::Error::Term(crate::zenoh_error!(error)))?;

    let queryable_id = queryable.id();
    session_locked.insert_entity(
        queryable_id,
        Entity::Queryable(queryable, session_id_resource),
    )?;

    Ok((
        rustler::types::atom::ok(),
        rustler::ResourceArc::new(EntityGlobalIdResource::new(queryable_id)),
    ))
}
